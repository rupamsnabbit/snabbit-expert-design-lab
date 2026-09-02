import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:chucker_flutter/chucker_flutter.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snabbit_runner/models/app_config.dart';
import 'package:snabbit_runner/services/app_config_channel.dart';
import 'package:snabbit_runner/modules/snabbit_shield/safety_shield_adapter.dart';
import 'package:snabbit_runner/services/deeplink/deeplink_result.dart';
import 'package:snabbit_runner/modules/snabbit_shield/snabbit_shield_upload_queue.dart';
import 'package:snabbit_runner/services/notification_service.dart';
import 'package:snabbit_runner/services/server_requests/config_http.dart';
import 'package:snabbit_runner/utils/app_strings.dart';

enum AppErrorType {
  none,
  noInternet,
  serverDown,
  securityError,
  invalidRequest,
  otherError;

  String? get description {
    switch (this) {
      case AppErrorType.none:
        return null;
      case AppErrorType.noInternet:
        return "Device is not connected to internet";
      case AppErrorType.serverDown:
        return "Request timed out due to poor internet connection";
      case AppErrorType.securityError:
        return "Secure connection could not be established";
      case AppErrorType.invalidRequest:
        return "Bad request error from server";
      case AppErrorType.otherError:
        return "Something went wrong";
    }
  }
}

// Base14 (Scout) OTLP/HTTP collector endpoint — single tenant for prod + non-
// prod today; prod vs staging is signalled by `serviceName` / `environment`
// labels inside base14_monitoring_service.dart, not by a different endpoint.
const String base14Endpoint =
    'https://rum.aps1-scout.base14.io/01ktk6g3gng7dyynm20wbfbgfc/otlp';

class Env {
  String name;
  String remoteUrl;
  String onboardingUrl;
  String atlasUrl;
  String bffUrl;
  String payoutsUrl;

  Env({
    required this.name,
    required this.remoteUrl,
    required this.onboardingUrl,
    required this.atlasUrl,
    this.bffUrl = '',
    this.payoutsUrl = '',
  });
}

const String _prodBffUrl = 'https://bff-service.snabbit.com/api/';
const String _stagingBffUrl = 'https://bff-service.stg.snabbit.net/api/';

// Post-migration stage stack (internal, *.stg.snabbit.net — VPN only).
// Shared by every non-prod env; the old api-staging.snabbit.com /
// staging-customer-envN.snabbit.com gateways are retired.
const String _stagingRemoteUrl = 'https://maestro-core.stg.snabbit.net/';
const String _stagingOnboardingUrl = 'https://opero.stg.snabbit.net/';
const String _stagingAtlasUrl = 'https://atlas-iot.stg.snabbit.net/';
const String _stagingPayoutsUrl = 'https://payout-service.stg.snabbit.net/';

Env prodEnv = Env(
  name: 'PROD',
  remoteUrl: 'https://runner-apis.snabbit.com/',
  onboardingUrl: "https://api-expert.snabbit.com/opero/",
  atlasUrl: "https://api-expert.snabbit.com/atlas-iot/",
  bffUrl: _prodBffUrl,
  payoutsUrl: "https://runner-apis.snabbit.com/payouts/",
);
Env devEnv = Env(
  name: 'DEV',
  remoteUrl: _stagingRemoteUrl,
  onboardingUrl: _stagingOnboardingUrl,
  atlasUrl: _stagingAtlasUrl,
  bffUrl: _stagingBffUrl,
  payoutsUrl: _stagingPayoutsUrl,
);
Env localEnv = Env(
  name: 'LOCAL',
  // Android-emulator host loopback (reaches the dev machine's localhost). Override
  // per-developer via Debug Menu → CUSTOM; no machine-specific IP is committed.
  remoteUrl: 'http://10.0.2.2:8000/',
  onboardingUrl: "http://10.0.2.2:8080/",
  atlasUrl: _stagingAtlasUrl,
  bffUrl: _stagingBffUrl,
  payoutsUrl: _stagingPayoutsUrl,
);
Env alphaEnv = Env(
  name: 'ALPHA',
  remoteUrl: _stagingRemoteUrl,
  onboardingUrl: _stagingOnboardingUrl,
  atlasUrl: _stagingAtlasUrl,
  bffUrl: _stagingBffUrl,
  payoutsUrl: _stagingPayoutsUrl,
);
Env stagingEnv1 = Env(
  name: 'STAGING-ENV1',
  remoteUrl: _stagingRemoteUrl,
  onboardingUrl: _stagingOnboardingUrl,
  atlasUrl: _stagingAtlasUrl,
  bffUrl: _stagingBffUrl,
  payoutsUrl: _stagingPayoutsUrl,
);
Env stagingEnv3 = Env(
  name: 'STAGING-ENV3',
  remoteUrl: _stagingRemoteUrl,
  onboardingUrl: _stagingOnboardingUrl,
  atlasUrl: _stagingAtlasUrl,
  bffUrl: _stagingBffUrl,
  payoutsUrl: _stagingPayoutsUrl,
);
Env stagingEnv4 = Env(
  name: 'STAGING-ENV4',
  remoteUrl: _stagingRemoteUrl,
  onboardingUrl: _stagingOnboardingUrl,
  atlasUrl: _stagingAtlasUrl,
  bffUrl: _stagingBffUrl,
  payoutsUrl: _stagingPayoutsUrl,
);
Env kavachTestEnv = Env(
  name: 'KAVACH-TEST',
  // Dedicated shield-testing deploy, not part of the migration list — unchanged.
  remoteUrl: 'http://seafty-shield-testing-maestro-core.stg.snabbit.net/',
  onboardingUrl: _stagingOnboardingUrl,
  atlasUrl: _stagingAtlasUrl,
  bffUrl: _stagingBffUrl,
  payoutsUrl: _stagingPayoutsUrl,
);

class GlobalState {
  ValueNotifier<AppErrorType> appError = ValueNotifier(AppErrorType.none);
  Env currentEnv = prodEnv;

  // Env currentEnv = stagingEnv3;
  // Env currentEnv = kavachTestEnv;
  // Env currentEnv = alphaEnv;

  // Env currentEnv = devEnv;
  // Env currentEnv = stagingEnv1;

  String get remoteUrl {
    return currentEnv.remoteUrl;
  }

  /// When true and [kDebugMode] is on, runner state merges sample
  /// `cooking_preference` into `RUNNER_JOB_IN_PROGRESS` widget_data if the API omits it.
  /// Set to `false` once the backend returns this field (or to verify real payloads).
  bool debugMockCookingPreferenceInJobInProgress = true;

  bool get effectiveDebugMockCookingPreferenceInJobInProgress =>
      kDebugMode && debugMockCookingPreferenceInJobInProgress;

  /// When non-null in [kDebugMode], [RunnerHttp.runnerAppCurrentState] skips the
  /// network (and location/battery work) and returns this map as JSON body with
  /// status 200. Set via [applyDebugRunnerAppCurrentStateStub] from the debug
  /// menu; defaults to `null` (real API).
  Map<String, dynamic>? debugStubRunnerAppCurrentStateBody;

  bool get effectiveDebugStubRunnerAppCurrentState =>
      kDebugMode && debugStubRunnerAppCurrentStateBody != null;

  /// Debug-menu override for the webview base URL used by `buildWebviewUrl`,
  /// set from the "Select Webview Environment" picker. `null` means no
  /// override (Remote Config is used). Honoured only in [kDebugMode];
  /// persisted under SharedPreferences key `debug_webview_base_url`.
  String? debugWebviewBaseUrl;

  /// Debug-menu override that forces `OtpService.currentProvider` to return
  /// `OtpServiceProvider.edumarc`. Referenced by `otp_service.dart`. The UI
  /// that flips this lives in PR #326 (Select Debug OTP Provider picker),
  /// which lost the merge to PR #323 on this branch — so the field stays
  /// `false` here. Kept declared so `otp_service.dart` compiles.
  bool debugForceEdumarcOtpProvider = false;

  /// Debug-menu sound-volume override (0.0–1.0) backing `desiredVolume`, so it
  /// scales every in-app `.play()` call and disables `setMaxVolume`. `null`
  /// means no override (full volume + force-max, as in prod). Honoured only in
  /// [kDebugMode]; persisted under SharedPreferences key `debug_sound_volume`.
  double? debugSoundVolume;

  /// Debug-menu toggle for the Chucker network-inspector in-app notification.
  /// Defaults to `false` (off) to keep debug runs non-intrusive. Applied via
  /// `applyChuckerDebugSettings` (debug-only). Honoured only in [kDebugMode];
  /// persisted under SharedPreferences key `debug_chucker_show_notification`.
  /// Plain `bool` so no Chucker type leaks into always-compiled code.
  bool debugChuckerShowNotification = false;

  /// Debug-menu selection for the Chucker notification alignment, stored as a
  /// preset key (e.g. `topCenter`, `bottomCenter`, `center`, `topRight`,
  /// `bottomRight`) and mapped to an `Alignment` in `applyChuckerDebugSettings`.
  /// Honoured only in [kDebugMode]; persisted under SharedPreferences key
  /// `debug_chucker_notification_alignment`. Plain `String` (no Chucker type).
  String debugChuckerNotificationAlignment = 'bottomCenter';

  AppConfig? appConfig;
  int? latestVersionCode;
  // Per-runner Android force-update floor from /runners/me (null unless targeted).
  int? runnerMinAndroidVersion;
  int? runnerSkipAndroidVersion;
  ShieldUploadQueue? shieldUploadQueue;
  SafetyShieldAdapter? shieldAdapter;
  String deviceId = '';

  /// True only in a background isolate (the background-service entrypoint or the
  /// FCM background handler set this on start). [GlobalState] is per-isolate, so
  /// the main/UI isolate keeps this `false`. Used purely to tag diagnostics that
  /// otherwise can't tell foreground from background (e.g. `ACCESS_TOKEN_NULL_ON_READ`).
  bool isBackgroundIsolate = false;

  // In debug builds, the app's root navigator key IS the Chucker inspector's
  // navigator key, so Chucker can resolve a Navigator to show its inspector
  // (its recommended integration — the legacy navigatorObserver is unreliable).
  // In release, kDebugMode folds to false and the ChuckerFlutter reference is
  // tree-shaken, leaving a plain navigator key. See DebugNetworkInspector.
  final GlobalKey<NavigatorState> navigatorKey =
      kDebugMode ? ChuckerFlutter.navigatorKey : GlobalKey<NavigatorState>();

  /// Single-slot pending deeplink: set by [DeepLinkRouter] when a link arrives
  /// before the app is routable (cold start / logged out), drained when
  /// PartnerHome mounts. Last-wins (a runner opens the app from one tap).
  /// In-memory only — a link always arrives within the launch that will reach
  /// PartnerHome, so it never needs to survive a process death.
  ({Uri uri, DeeplinkSource source})? pendingDeeplink;

  String serverPath(String p) {
    return remoteUrl + p;
  }

  String onboardingUrlServerPath(String path) {
    return "${currentEnv.onboardingUrl}$path";
  }

  String get bffUrl => currentEnv.bffUrl;

  String bffServerPath(String path) {
    return "${currentEnv.bffUrl}$path";
  }

  String atlasServerPath(String path) {
    return "${currentEnv.atlasUrl}$path";
  }

  String get payoutsUrl => currentEnv.payoutsUrl;

  String payoutsServerPath(String path) {
    return "${currentEnv.payoutsUrl}$path";
  }

  AudioPlayer audioPlayer = AudioPlayer();

  bool showSnabbitCongratsPopup = false;

  bool canEditPermanentAddress = false;
  bool canEditDob = false;

  // String appVersion;
  SharedPreferences? prefs;

  static final GlobalState _globalState = GlobalState._internal();

  localNotify(int id, String title) async {
    AndroidNotificationDetails androidNotificationDetails =
        const AndroidNotificationDetails(
      'local_notifications_from_device',
      'local notifications from device',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      // enableVibration: true,
      // vibrationPattern: Int64List.fromList([0, 1000, 500, 2000]),
      // sound: RawResourceAndroidNotificationSound('custom_sound'),
      // playSound: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
    );
    NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);

    await NotificationService.instance.flutterLocalNotificationsPlugin.show(
      id,
      title,
      null,
      notificationDetails,
    );
  }

  Future<String> currentVersionCode() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.buildNumber;
    } catch (e) {
      debugPrint('Error getting current version code: $e');
      return '';
    }
  }

  Future<void> setLatestVersionCode() async {
    try {
      latestVersionCode = int.tryParse(await currentVersionCode());
    } catch (e) {
      // DO NOTHING
    }
  }

  bool _isVersionBelow(int? floor) =>
      latestVersionCode != null && floor != null && latestVersionCode! < floor;

  bool _isBelowSkipFloor(int? floor, int skipped) =>
      floor != null && _isVersionBelow(floor) && skipped < floor;

  bool isAndroidUpdateRequired() {
    try {
      if (isCurrentVersionInvalid()) return true;
      if (_isVersionBelow(appConfig?.minAndroidVersion)) return true;
      if (_isVersionBelow(runnerMinAndroidVersion)) return true;
      return false;
    } catch (e) {
      return false;
    }
  }

  /// True when the force-update decision was made from MISSING inputs rather than a
  /// real comparison — [isAndroidUpdateRequired] returns false by the ABSENCE of an
  /// input, not because the build is compliant. Two silent fail-opens:
  ///   - [latestVersionCode] is null (PackageInfo failed / buildNumber unparseable),
  ///     so every `_isVersionBelow` short-circuits to false regardless of the floors;
  ///   - neither floor loaded (app_config fetch failed silently → [appConfig] null,
  ///     and no per-runner floor).
  /// Callers gating on [isAndroidUpdateRequired] can surface this to tell a silent
  /// fail-open apart from a genuine compliant pass.
  bool get androidUpdateCheckIndeterminate =>
      latestVersionCode == null ||
      (appConfig?.minAndroidVersion == null && runnerMinAndroidVersion == null);

  bool isSkipAndroidUpdateRequired() {
    try {
      final skipped = prefs?.getInt(AppStrings.versionCodeSkipped) ?? 0;
      if (_isBelowSkipFloor(appConfig?.skipAndroidVersion, skipped)) {
        return true;
      }
      if (_isBelowSkipFloor(runnerSkipAndroidVersion, skipped)) return true;
      return false;
    } catch (e) {
      return false;
    }
  }

  factory GlobalState() {
    return _globalState;
  }

  GlobalState._internal();

  Future<void> setAppConfig() async {
    try {
      Response? response = await ConfigHttp.getAppConfig();
      if (response != null) {
        appConfig = AppConfig.fromJson(response.data);
        // Mirror the raw document into the KMP AppConfigStore so :shared
        // features can decode their config slices (job_support → FR-11).
        // Best-effort: the channel logs + absorbs its own failures.
        if (response.data is Map<String, dynamic>) {
          AppConfigChannel.pushConfig(jsonEncode(response.data));
        }
        final repeat = appConfig?.expertNotMovingRepeatCount;
        if (repeat != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt(AppStrings.expertNotMovingRepeatCountKey, repeat);
        }
      }
    } catch (e) {
      // DO NOTHING
    }
  }

  bool isCurrentVersionInvalid() {
    try {
      return latestVersionCode != null &&
          appConfig?.invalidVersionCodes?.contains(latestVersionCode!) == true;
    } catch (e) {
      return false;
    }
  }

  /// Load saved environment from SharedPreferences and apply to GlobalState
  Future<void> loadSavedEnvironment() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Webview override — loaded before the early-return below so it works
      // even with no app environment saved. Debug builds only: the picker
      // that writes this pref is kDebugMode-gated, so a stale value can't
      // redirect webviews in a release build.
      if (kDebugMode) {
        final savedWebviewBaseUrl = prefs.getString('debug_webview_base_url');
        if (savedWebviewBaseUrl != null && savedWebviewBaseUrl.isNotEmpty) {
          debugWebviewBaseUrl = savedWebviewBaseUrl;
          debugPrint('Loaded webview base URL override: $savedWebviewBaseUrl');
        }
      }

      // Debug-only OTP provider override — also loaded before the
      // early-return below so it works even with no app environment saved.
      // kDebugMode-gated so a stale pref can't affect a release build.
      if (kDebugMode) {
        debugForceEdumarcOtpProvider =
            prefs.getBool('debug_force_edumarc_otp') ?? false;
        debugSoundVolume = prefs.getDouble('debug_sound_volume');
        debugChuckerShowNotification =
            prefs.getBool('debug_chucker_show_notification') ?? false;
        debugChuckerNotificationAlignment =
            prefs.getString('debug_chucker_notification_alignment') ??
                'bottomCenter';
      }

      final savedEnv = prefs.getString('debug_selected_env');
      if (savedEnv == null) {
        // No saved environment, keep current default (prodEnv)
        return;
      }

      if (savedEnv == 'CUSTOM') {
        // Load custom environment
        final remoteUrl = prefs.getString('debug_custom_remote_url');
        final onboardingUrl = prefs.getString('debug_custom_onboarding_url');
        final atlasUrl = prefs.getString('debug_custom_atlas_url');
        final bffUrl = prefs.getString('debug_custom_bff_url');
        final payoutsUrl = prefs.getString('debug_custom_payouts_url');

        if (remoteUrl != null && onboardingUrl != null && atlasUrl != null) {
          currentEnv = Env(
            name: 'CUSTOM',
            remoteUrl: remoteUrl,
            onboardingUrl: onboardingUrl,
            atlasUrl: atlasUrl,
            bffUrl: bffUrl ?? '',
            payoutsUrl: payoutsUrl ?? '',
          );
          debugPrint('Loaded custom environment: $remoteUrl');
        }
      } else {
        // Load predefined environment
        switch (savedEnv) {
          case 'PROD':
            currentEnv = prodEnv;
            break;
          case 'DEV':
            currentEnv = devEnv;
            break;
          case 'LOCAL':
            currentEnv = localEnv;
            break;
          case 'ALPHA':
            currentEnv = alphaEnv;
            break;
          case 'STAGING-ENV1':
            currentEnv = stagingEnv1;
            break;
          case 'STAGING-ENV3':
            currentEnv = stagingEnv3;
            break;
          case 'STAGING-ENV4':
            currentEnv = stagingEnv4;
            break;
          case 'KAVACH-TEST':
            currentEnv = kavachTestEnv;
            break;
        }
        debugPrint('Loaded environment: ${currentEnv.name}');
      }
    } catch (e) {
      debugPrint('Error loading saved environment: $e');
      // Keep current default on error
    }
  }
}
