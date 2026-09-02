import 'dart:async';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/services/shorebird/shorebird_manager.dart';

import 'auth_events_channel.dart';
import 'auth_token_channel.dart';
import 'globals.dart';
import 'network_config_channel.dart';

/// Single Dart-side entry point to the KMP module's network surface.
///
/// Fans out to per-concern channels:
///  - `com.snabbit.runner/network_config` — baseUrl + versionCode
///  - `com.snabbit.runner/auth`            — token push/clear
///  - `com.snabbit.runner/auth_events`     — 401 stream
///
/// Most callers should use this facade. Reach for the underlying
/// [NetworkConfigChannel] / [AuthTokenChannel] / [AuthEventsChannel] only
/// when a single concern is needed (e.g. token-only refresh).
class NetworkChannel {
  NetworkChannel._();

  static StreamSubscription<void>? _authSub;

  /// Cold-start setup: pushes baseUrl + versionCode and, if provided, the
  /// current bearer token. Combines two state writes behind one entry
  /// point because every cold-start caller needs both — splitting would
  /// just push the orchestration to every call site.
  ///
  /// Token is optional (null on first-install / pre-login).
  static Future<void> bootstrap({
    required String baseUrl,
    required String versionCode,
    String? token,
  }) async {
    await NetworkConfigChannel.pushConfig(
      baseUrl: baseUrl,
      versionCode: versionCode,
      // Onboarding host (a different base than baseUrl) — KMP's PAN update needs it.
      onboardingUrl: GlobalState().onboardingUrlServerPath(''),
      // Prod flag for the native Profile footer (hides the endpoint line in prod).
      isProd: GlobalState().currentEnv == prodEnv,
    );
    if (token != null && token.isNotEmpty) {
      await AuthTokenChannel.pushToken(token);
    }
    // The Profile footer's "App version X+Y" label comes from Shorebird +
    // PackageInfo (both async). Push it as a non-blocking follow-up so it never
    // delays the baseUrl push that gates every KMP HTTP call.
    unawaited(_pushAppVersionLabel(baseUrl, versionCode));
  }

  /// Best-effort push of the app-version label for KMP's Profile footer.
  static Future<void> _pushAppVersionLabel(
    String baseUrl,
    String versionCode,
  ) async {
    try {
      final version = await ShorebirdManager.instance.getAppVersion();
      final info = await PackageInfo.fromPlatform();
      await NetworkConfigChannel.pushConfig(
        baseUrl: baseUrl,
        versionCode: versionCode,
        onboardingUrl: GlobalState().onboardingUrlServerPath(''),
        isProd: GlobalState().currentEnv == prodEnv,
        appVersion: 'App version $version+${info.buildNumber}',
      );
    } catch (e) {
      MonitoringServiceHelper.logError(
        'kmp_app_version_push_failed',
        {'error': e.toString()},
      );
    }
  }

  /// Wipes the bearer token from KMP. Called on logout and from `handle403`.
  static Future<void> clearToken() => AuthTokenChannel.clearToken();

  /// Best-effort post-login KMP setup. Bundles the same baseUrl/versionCode
  /// reads the three OTP flows used to do inline, and reports any failure
  /// via MonitoringServiceHelper rather than just dropping it to
  /// `debugPrint` — production has no logcat to grep.
  ///
  /// Does NOT throw to the caller: the Dart HTTP path has the token from
  /// SecureStorage already, so a KMP push failure only degrades the KMP
  /// pipeline and shouldn't block navigation.
  static Future<void> pushTokenAfterLogin(String token) async {
    try {
      await bootstrap(
        baseUrl: GlobalState().remoteUrl,
        versionCode: '${GlobalState().latestVersionCode ?? 0}',
        token: token,
      );
    } catch (e) {
      MonitoringServiceHelper.logError(
        'KMP_POST_LOGIN_TOKEN_PUSH_FAILED',
        {
          'error': e.toString(),
          'baseUrl': GlobalState().remoteUrl,
        },
      );
    }
  }

  /// Installs the 401 listener. Call once at app start, before any HTTP
  /// request fires. Replaces any prior listener — calling repeatedly is
  /// safe.
  static void onUnauthorized(void Function() handler) {
    _authSub?.cancel();
    _authSub = AuthEventsChannel.onUnauthorized(handler);
  }
}
