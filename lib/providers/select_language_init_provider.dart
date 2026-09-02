import 'dart:async';
import 'dart:io';
import 'package:snabbit_runner/services/analytics/kmp_analytics_channel.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snabbit_runner/services/security/secure_storage_service.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import '../services/file_ops.dart' show getContacts;
import '../services/globals.dart';
import '../services/http_service.dart';
import '../services/monitoring/monitoring_service_helper.dart';
import '../services/shorebird/shorebird_manager.dart';

/// Provider for handling SelectLanguageV2 screen initialization tasks
class SelectLanguageInitProvider extends ChangeNotifier {
  // 7 attempts => 1+2+4+8+16+32 = 63s of backoff. Play Services can answer
  // SERVICE_NOT_AVAILABLE for well over the ~15s the previous 5 attempts
  // allowed, especially on a fresh install.
  static const int _maxFcmRetries = 7;

  /// Last successfully reported `<versionCode>|<token>`. Persisted so a
  /// successful report survives the process and an upgrade re-reports itself.
  static const String _fcmSignatureKey = 'fcm_last_reported_signature';

  // Static so the app-resume hook in main.dart can drive registration: the
  // root WidgetsBindingObserver sits above the MultiProvider that creates this
  // provider, so it cannot reach an instance through context.
  static bool _fcmRegistrationInProgress = false;
  static bool _tokenRefreshSubscribed = false;

  bool _contactsSyncInProgress = false;

  void initializeServices(UserProfile userProfile) {
    unawaited(ensureFcmReported());
    syncContacts(userProfile);
  }

  /// Reports the FCM token + running build to the backend unless the last
  /// successful report already covers this build.
  ///
  /// Cheap no-op in the steady state (one SharedPreferences read — no
  /// getToken, no network), so it is safe to call on every app resume. That
  /// is what makes reporting self-healing: a transient failure at login no
  /// longer costs the whole session, and an upgrade re-reports on its own.
  static Future<void> ensureFcmReported() async {
    if (_fcmRegistrationInProgress) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();

      if (!needsReport(
        persisted: prefs.getString(_fcmSignatureKey),
        currentVersionCode: packageInfo.buildNumber,
      )) {
        return;
      }

      // Registration used to run only from SelectLanguageV2, which is
      // unreachable without a token. The resume triggers are not, so the auth
      // state has to be checked here: an unauthenticated POST returns 401,
      // and HttpService routes that into handle403() — a full force-logout
      // that clears secure storage and tears down the MQTT engine. Reporting
      // an app version must never be able to log anyone out, so skip and let
      // the next trigger pick it up.
      final String? accessToken = await SecureStorageUtils.getAccessToken(
        'FCM_ENSURE_REPORTED',
      );
      if (accessToken == null || accessToken.isEmpty) return;

      await _runFcmRegistrationWithRetry(packageInfo);
    } catch (e, stackTrace) {
      MonitoringServiceHelper.logError(
        'fcm_initialization_error',
        {
          'error': e.toString(),
          'stack_trace': stackTrace.toString(),
        },
      );
    }
  }

  /// The value persisted after a successful report.
  @visibleForTesting
  static String fcmSignature({
    required String versionCode,
    required String token,
  }) =>
      '$versionCode|$token';

  /// Whether the backend still needs to hear from us. True when nothing was
  /// ever reported, or when the reported build differs from the running one.
  ///
  /// Deliberately does not consider the token: checking it would mean calling
  /// getToken() on every resume. Rotation is handled by the onTokenRefresh
  /// subscription below, which clears the persisted signature instead.
  @visibleForTesting
  static bool needsReport({
    required String? persisted,
    required String currentVersionCode,
  }) =>
      persisted == null || !persisted.startsWith('$currentVersionCode|');

  /// Runs FCM registration with exponential backoff
  static Future<void> _runFcmRegistrationWithRetry(
    PackageInfo packageInfo,
  ) async {
    if (_fcmRegistrationInProgress) return;

    _fcmRegistrationInProgress = true;

    try {
      final FirebaseMessaging messaging = FirebaseMessaging.instance;
      final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

      int attempt = 0;
      bool success = false;
      String? reportedToken;

      while (attempt < _maxFcmRetries && !success) {
        attempt++;
        try {
          // getToken() belongs inside the loop, not hoisted above it: Play
          // Services answers SERVICE_NOT_AVAILABLE while it is still settling
          // — most often right after a fresh install, which is exactly when
          // there is no earlier registration to fall back on. Hoisted, a
          // single transient blip skipped registration for the whole session.
          final String? token = await messaging.getToken();

          if (token == null) {
            throw Exception('FCM token is null');
          }

          KmpAnalyticsChannel.instance.registerCleverTapToken(token);
          _subscribeToTokenRefresh(messaging);

          await _requestAndSendFcmTokenOnce(
            token: token,
            deviceInfo: deviceInfo,
            packageInfo: packageInfo,
          );
          success = true;
          reportedToken = token;
        } catch (e, stackTrace) {
          // Log quietly; do not impact UI.
          MonitoringServiceHelper.logError(
            'firebase_messaging_error_background_retry',
            {
              'attempt': attempt.toString(),
              'error': e.toString(),
              'stack_trace': stackTrace.toString(),
            },
          );
          if (attempt < _maxFcmRetries) {
            // Exponential backoff: 1s, 2s, 4s, 8s, 16s, 32s
            final delay = Duration(seconds: 1 << (attempt - 1));
            await Future.delayed(delay);
          }
        }
      }

      if (success && reportedToken != null) {
        // Persisted outside the attempt loop so a SharedPreferences failure
        // can't be logged as a send failure or burn another attempt. Worst
        // case the write fails and the next resume re-reports — the endpoint
        // is an upsert, so that is wasteful rather than wrong.
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          _fcmSignatureKey,
          fcmSignature(
            versionCode: packageInfo.buildNumber,
            token: reportedToken,
          ),
        );
      }

      if (!success) {
        MonitoringServiceHelper.logError(
          'fcm_registration_retry_exhausted',
          {'attempts': attempt.toString()},
        );
      }
    } catch (e, stackTrace) {
      MonitoringServiceHelper.logError(
        'fcm_initialization_error',
        {
          'error': e.toString(),
          'stack_trace': stackTrace.toString(),
        },
      );
    } finally {
      // In a finally, not after the catch: the flag is static and now gates
      // every trigger, so a throw on the error path would otherwise wedge it
      // true and disable reporting for the rest of the process.
      _fcmRegistrationInProgress = false;
    }
  }

  /// FCM rotates tokens (reinstall, data clear, Play Services events). The
  /// removed CleverTap plugin handled this; we own it now. Subscribed once —
  /// the retry loop above can reach this on every attempt. Intentionally
  /// app-lifetime, so there is no subscription to cancel.
  static void _subscribeToTokenRefresh(FirebaseMessaging messaging) {
    if (_tokenRefreshSubscribed) return;
    _tokenRefreshSubscribed = true;

    messaging.onTokenRefresh.listen((token) async {
      KmpAnalyticsChannel.instance.registerCleverTapToken(token);
      try {
        // Drop the persisted signature so the next trigger reports the new
        // token — needsReport() only compares the version, by design.
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_fcmSignatureKey);
      } catch (e) {
        MonitoringServiceHelper.logError(
          'fcm_signature_clear_failed',
          {'error': e.toString()},
        );
      }
    });
  }

  /// Single attempt to get and send the FCM token
  static Future<void> _requestAndSendFcmTokenOnce({
    required String token,
    required DeviceInfoPlugin deviceInfo,
    required PackageInfo packageInfo,
  }) async {
    try {
      Map<String, dynamic> deviceData = {};

      if (Platform.isAndroid) {
        final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        deviceData = {
          'token': token,
          'device_id': GlobalState().deviceId,
          'device_model': androidInfo.model,
          'os_version': 'Android ${androidInfo.version.release}',
          'device_manufacturer': androidInfo.manufacturer,
          'app_version': packageInfo.version,
          'app_version_code': packageInfo.buildNumber,
          'shorebird_patch_number':
              ShorebirdManager.instance.currentPatchNumber?.toString(),
        };
      }

      await HttpService().post(
        GlobalState().serverPath('api/v1/users/me/register_fcm_token'),
        data: deviceData,
        headers: {},
        // Defence in depth alongside the token check in ensureFcmReported():
        // a 401 here would otherwise trigger handle403(), force-logging the
        // runner out and tearing down the MQTT engine. The token can read
        // empty transiently (see the background cold-start secure-storage
        // issue), and version reporting must never cost a session — a failed
        // attempt is retried by the loop and the next trigger instead.
        suppressUnauthorizedHandler: true,
      );
      debugPrint('FCM token sent to server successfully');
    } catch (e) {
      debugPrint('Error in _requestAndSendFcmTokenOnce: $e');
      rethrow;
    }
  }

  /// Sync contacts if allowed by user profile
  Future<void> syncContacts(UserProfile? userProfile) async {
    if (userProfile?.syncReferral != true || _contactsSyncInProgress) return;

    _contactsSyncInProgress = true;

    try {
      // Track getContacts
      final Trace getContactsTrace =
          FirebasePerformance.instance.newTrace('get_contacts');
      getContactsTrace.start();

      // Get and process contacts
      await getContacts();

      getContactsTrace.stop();
    } finally {
      _contactsSyncInProgress = false;
    }
  }
}
