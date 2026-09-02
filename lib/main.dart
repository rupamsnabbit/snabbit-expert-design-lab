import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:chucker_flutter/chucker_flutter.dart';
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:scout_flutter/scout_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snabbit_runner/home/providers/info_banner_provider.dart';
import 'package:snabbit_runner/models/awol/awol_models.dart';
import 'package:snabbit_runner/services/awol_alarm_service.dart';
import 'package:snabbit_runner/pages/chat/chat_screen.dart';
import 'package:snabbit_runner/providers/provisional_attendance_before_logout_provider.dart';
import 'package:snabbit_runner/services/deeplink/deeplink_router.dart';
import 'package:snabbit_runner/services/navigation/kmp_navigation_bridge.dart';
import 'package:snabbit_runner/services/language_channel.dart';
import 'package:snabbit_runner/services/notification_service.dart';
import 'package:snabbit_runner/pages/getting_started/debug_menu.dart';
import 'package:snabbit_runner/pages/getting_started/getting_started.dart';
import 'package:snabbit_runner/pages/getting_started/learn_more.dart';
import 'package:snabbit_runner/pages/frontend_preview/frontend_preview_home.dart';
import 'package:snabbit_runner/pages/go_live/confirm_shift_timings.dart';
import 'package:snabbit_runner/pages/go_live/device_testing.dart';
import 'package:snabbit_runner/pages/go_live/phone_integrity_check.dart';
import 'package:snabbit_runner/pages/go_live/potential_earnings.dart';
import 'package:snabbit_runner/pages/go_live/tnc_accept.dart';
import 'package:snabbit_runner/pages/go_live/training_details.dart';
import 'package:snabbit_runner/pages/go_live/uniform_confirmation.dart';
import 'package:snabbit_runner/pages/go_live/weekend_earnings.dart';
import 'package:snabbit_runner/pages/go_live/go_live_v2/go_live_flow_controller.dart';
import 'package:snabbit_runner/pages/insurance_support.dart';
import 'package:snabbit_runner/pages/language_home.dart';
import 'package:snabbit_runner/pages/login/select_language_v2.dart';
import 'package:snabbit_runner/pages/login/send_otp.dart';
import 'package:snabbit_runner/pages/payout/bonus_home.dart';
import 'package:snabbit_runner/pages/payout/deduction_details.dart';
import 'package:snabbit_runner/pages/payout/early_payouts/early_payouts_screen.dart';
import 'package:snabbit_runner/pages/payout/incentive_details.dart';
import 'package:snabbit_runner/pages/payout/transaction_history.dart';
import 'package:snabbit_runner/pages/raise_dispute/issue_history.dart';
import 'package:snabbit_runner/pages/raise_dispute/new_issue_reporter.dart';
import 'package:snabbit_runner/pages/referral_home.dart';
import 'package:snabbit_runner/pages/app_web_view_page.dart';
import 'package:snabbit_runner/pages/signup/aadhaar_details.dart';
import 'package:snabbit_runner/pages/signup/aadhaar_number_updater.dart';
import 'package:snabbit_runner/pages/aadhaar_reverification/aadhaar_reverification_page.dart';
import 'package:snabbit_runner/pages/signup/aadhaar_validator.dart';
import 'package:snabbit_runner/pages/signup/availability_details.dart';
import 'package:snabbit_runner/pages/signup/bank_details.dart';
import 'package:snabbit_runner/pages/signup/bank_details/account_confirmation_tnc.dart';
import 'package:snabbit_runner/pages/signup/bank_details/account_otp_verification.dart';
import 'package:snabbit_runner/pages/signup/bank_details/add_bank_or_upi_details_screen.dart';
import 'package:snabbit_runner/pages/signup/bank_details/bank_account_details_screen.dart';
import 'package:snabbit_runner/pages/signup/bank_details/enter_bank_details.dart';
import 'package:snabbit_runner/pages/signup/bank_details/enter_upi_details.dart';
import 'package:snabbit_runner/pages/signup/bank_details/upi_details_screen.dart';
import 'package:snabbit_runner/pages/signup/family_details/family_details.dart';
import 'package:snabbit_runner/pages/signup/family_details/family_details_divorced.dart';
import 'package:snabbit_runner/pages/signup/family_details/family_details_married.dart';
import 'package:snabbit_runner/pages/signup/family_details/family_details_unmarried.dart';
import 'package:snabbit_runner/pages/signup/family_details/family_details_widowed.dart';
import 'package:snabbit_runner/pages/signup/insurance/children_details.dart';
import 'package:snabbit_runner/pages/signup/insurance_details.dart';
import 'package:snabbit_runner/pages/signup/integrity_test.dart';
import 'package:snabbit_runner/pages/signup/location_change_v2.dart';
import 'package:snabbit_runner/pages/signup/onboarding_screen.dart';
import 'package:snabbit_runner/pages/signup/onboarding_v2/onboarding_multiple_questions_screen.dart';
import 'package:snabbit_runner/pages/signup/onboarding_v2/onboarding_single_question_screen.dart';
import 'package:snabbit_runner/pages/signup/pan_number_updater.dart';
import 'package:snabbit_runner/pages/signup/personal_details.dart';
import 'package:snabbit_runner/pages/signup/prior_experience.dart';
import 'package:snabbit_runner/pages/signup/registration_code.dart';
import 'package:snabbit_runner/pages/signup/registration_code_v2.dart';
import 'package:snabbit_runner/pages/signup/select_service.dart';
import 'package:snabbit_runner/pages/signup/review/personal_details_review_v3.dart';
import 'package:snabbit_runner/pages/signup/review/registration_review.dart';
import 'package:snabbit_runner/pages/signup/training_slots.dart';
import 'package:snabbit_runner/pages/signup/upload_documents.dart';
import 'package:snabbit_runner/pages/signup/upload_aadhaar_photos.dart';
import 'package:snabbit_runner/pages/signup/voter_id_updater.dart';
import 'package:snabbit_runner/pages/signup/work_experience.dart';
import 'package:snabbit_runner/pages/verification_display.dart';
import 'package:snabbit_runner/payout/bonus/pages/festive_bonus_screen.dart';
import 'package:snabbit_runner/providers/contest_data_provider.dart';
import 'package:snabbit_runner/providers/aadhaar_reverification_provider.dart';
import 'package:snabbit_runner/providers/credentials_management_provider.dart';
import 'package:snabbit_runner/providers/daily_earnings_provider.dart';
import 'package:snabbit_runner/providers/documents_provider.dart';
import 'package:snabbit_runner/providers/early_payouts_provider.dart';
import 'package:snabbit_runner/providers/insurance_profile_provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/loan_provider.dart';
import 'package:snabbit_runner/providers/onboarding_steps_provider.dart';
import 'package:snabbit_runner/providers/partner_home_init_provider.dart';
import 'package:snabbit_runner/providers/payout.dart';
import 'package:snabbit_runner/providers/payout_history_provider.dart';
import 'package:snabbit_runner/providers/potential_earnings_provider.dart';
import 'package:snabbit_runner/providers/referral.dart';
import 'package:snabbit_runner/providers/period_leave_provider.dart';
import 'package:snabbit_runner/providers/runner_rt_data.dart';
import 'package:snabbit_runner/providers/select_language_init_provider.dart';
import 'package:snabbit_runner/providers/selfie_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/referrals/pages/diwali_contest_page.dart';
import 'package:snabbit_runner/referrals/pages/referral_contacts.dart';
import 'package:snabbit_runner/referrals/pages/wallet.dart';
import 'package:snabbit_runner/referrals/providers/wallet_provider.dart';
import 'package:snabbit_runner/services/analytics/analytics_service.dart';
import 'package:snabbit_runner/services/debug/chucker_debug.dart';
import 'package:snabbit_runner/services/monitoring/kmp_crash_reporter_bridge.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/services/network/qa_proxy.dart';
import 'package:snabbit_runner/services/realtime/mqtt_cohort_cache.dart';
import 'package:snabbit_runner/services/realtime/realtime_channel.dart';
import 'package:snabbit_runner/services/iot/background/iot_background_manager.dart';
import 'package:snabbit_runner/services/iot/config/config_service.dart';
import 'package:snabbit_runner/services/iot/diagnostics/iot_diagnostics_reporter.dart';
import 'package:snabbit_runner/services/bcp/bcp_gate.dart';
import 'package:snabbit_runner/services/iot/diagnostics/iot_diagnostics_collector.dart';
import 'package:snabbit_runner/services/job_overlay_channel.dart';
import 'package:snabbit_runner/services/profile_actions_channel.dart';
import 'package:snabbit_runner/services/remote_config/kmp_remote_config_mirror.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_keys.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_service.dart';
import 'package:snabbit_runner/services/webview/capture_registry.dart';
import 'package:snabbit_runner/services/runner_http.dart';
import 'package:snabbit_runner/services/security/root_detection_service.dart';
import 'package:snabbit_runner/services/security/secure_storage_service.dart';
import 'package:snabbit_runner/services/shorebird/shorebird_manager.dart';
import 'package:snabbit_runner/utils/app_strings.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/nav_observer.dart';
import 'package:snabbit_runner/widgets/checkout_outside_job_location.dart';
import 'package:snabbit_runner/widgets/drawer/identity_card.dart';
import 'package:snabbit_runner/widgets/drawer/long_leave.dart';
import 'package:snabbit_runner/widgets/job_in_progress/on_the_job.dart';
import 'package:snabbit_runner/widgets/job_login/selfie_login.dart';
import 'package:snabbit_runner/widgets/job_login/selfie_preview.dart';
import 'package:snabbit_runner/widgets/location_permission_confirmation.dart';
import 'package:snabbit_runner/widgets/notification_permission_service.dart';
import 'package:snabbit_runner/widgets/payout/current_period_view.dart';
import 'package:snabbit_runner/widgets/raise_dispute/bottom_sheet.dart';
import 'package:snabbit_runner/widgets/sos.dart';
import 'package:snabbit_runner/widgets/upload_documents/onboarding_failed_view.dart';
import 'package:snabbit_runner/widgets/upload_documents/onboarding_status_view.dart';
import 'package:vibration/vibration.dart';

import 'firebase_options.dart';
import 'config/frontend_preview.dart';
import 'pages/go_live/shift_timings.dart';
import 'pages/partner_home.dart';
import 'pages/payout/attendance.dart';
import 'pages/payout/daily_earnings_list.dart';
import 'pages/payout/daily_earnings_state.dart';
import 'pages/payout/tips_info_screen.dart';
import 'pages/payout/net_earnings.dart';
import 'pages/payout/overtime_details.dart';
import 'pages/payout/payout_home.dart';
import 'pages/payout/performance.dart';
import 'pages/signup/availability_details_2.dart';
import 'pages/signup/customer_service.dart';
import 'pages/signup/skills.dart';
import 'pages/signup/training_progress.dart';
import 'pages/signup/upload_documents_pan.dart';
import 'providers/auto_ot_provider.dart';
import 'providers/banner_config_provider.dart';
import 'providers/current_picture_provider.dart';
import 'providers/daily_earnings.dart';
import 'providers/leave_model.dart';
import 'providers/tips_provider.dart';
import 'providers/pip_provider.dart';
import 'providers/overlay_provider.dart';
import 'providers/preferred_language_provider.dart';
import 'services/analytics/onboarding_analytics.dart';
import 'services/clevertap.dart';
import 'services/mixpanel_setup.dart';
import 'services/file_ops.dart';
import 'modules/snabbit_shield/snabbit_shield_database.dart';
import 'modules/snabbit_shield/snabbit_shield_upload_queue.dart';
import 'modules/snabbit_shield/snabbit_shield_permission_handler.dart';
import 'modules/snabbit_shield/shield_sos_push_store.dart';
import 'services/debug/network_inspector.dart';
import 'services/device_identifier.dart';
import 'services/globals.dart';
import 'services/http_service.dart' show handle403;
import 'services/network_channel.dart';
import 'services/localized_audio_service.dart';
import 'utils/themes.dart';
import 'utils/tracking_events.dart';
import 'widgets/job_in_progress/rating_block_handler.dart';

// for locking background service requests
bool _isBGPostRequestInProgress = false;
bool _isBGServiceRunning = false;

// The background-location service's ServiceInstance, captured while that
// service isolate is alive. It lets code running inside the isolate stop the
// service and talk back to the main isolate WITHOUT the main-isolate-only
// FlutterBackgroundService method channel — that channel
// (`id.flutter/background_service/android/method`) is registered on the main
// FlutterEngine and does not exist in the background isolate, so invoking it
// there throws MissingPluginException.
ServiceInstance? _bgServiceInstance;

// IoT background manager instance
IotBackgroundManager? _iotManager;
int _lastIotResurrectionAttempt = 0;

Future<bool> _ensureMicPermissionForBackgroundService() async {
  // First try Shield's shared mic handler (may show the system permission dialog).
  var result = await ShieldPermissionHandler.requestMicPermission();
  if (result == MicPermissionResult.granted) {
    return true;
  }

  // If we don't have a foreground context, we cannot show our custom dialog.
  final context = GlobalState().navigatorKey.currentContext;
  if (context == null) {
    return false;
  }

  // Show the same Shield dialog (handles permanentlyDenied → Open Settings).
  final grantedViaDialog = await ShieldPermissionHandler.showPermissionDialog(
    context,
    isPermanentlyDenied: result == MicPermissionResult.permanentlyDenied,
  );
  if (!grantedViaDialog) {
    return false;
  }

  // Re-check after dialog / Settings.
  result = await ShieldPermissionHandler.requestMicPermission();
  return result == MicPermissionResult.granted;
}

bool _isCleverTapPush(RemoteMessage message) {
  final data = message.data;
  return data.containsKey('wzrk_pn') ||
      data.keys.any((key) => key.startsWith('wzrk_'));
}

void _logNotificationReceived(RemoteMessage message, String state) {
  try {
    ClevertapSetup.logEvent(
      TrackingEvents.notificationReceived,
      {
        "state": state,
        "sent_time": message.sentTime?.toIso8601String(),
        ...message.data,
      },
    );
  } catch (_) {}
}

Future<void> _handleCleverTapPush(
  RemoteMessage message,
  String state,
) async {
  try {
    final data = message.data;
    // CleverTap is the sender; the app draws (custom rendering). The native
    // SnabbitPushService already fired CleverTap's "viewed" impression before
    // we got here, so all that's left is to render via our notification stack.
    await NotificationService.instance.createNotificationChannel();
    // Stable id so CleverTap re-deliveries of the same push replace instead
    // of stack. wzrk_pid is per-push-instance; fall back to FCM messageId.
    final stableId =
        (data['wzrk_pid'] ?? data['wzrk_id'] ?? message.messageId ?? '')
            .toString();
    // Title/body fallback chain: FCM notification block (rich push) → CleverTap
    // basic-push keys (nt/nm) → FCM standard keys (title/body). Prevents blank
    // notifications when a campaign doesn't use the basic-push template.
    await NotificationService.instance.showNotification(
      id: stableId.isEmpty ? message.hashCode : stableId.hashCode,
      title: message.notification?.title ??
          data['nt'] as String? ??
          data['title'] as String?,
      body: message.notification?.body ??
          data['nm'] as String? ??
          data['body'] as String?,
      payload: jsonEncode(data),
    );
  } catch (e) {
    MonitoringServiceHelper.logError(
      "FAILED_TO_SHOW_CLEVERTAP_NOTIFICATION",
      {
        "error": e.toString(),
        "state": state,
      },
    );
  }
}

bool _isFresh(RemoteMessage message,
    {Duration window = const Duration(minutes: 2)}) {
  final sent = message.sentTime;
  if (sent == null) return true;
  return DateTime.now().isBefore(sent.add(window));
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // GlobalState is per-isolate; this FCM-background isolate started with a
  // fresh singleton (currentEnv = prodEnv). Mirror the foreground main() so
  // any debug-menu env / overrides set by the user are honoured here too,
  // otherwise CUSTOM-env testers see API calls fired against prod URLs.
  // kDebugMode-gated to match the foreground load — a stale debug-menu env
  // pref must never redirect a release build's background API calls.
  if (kDebugMode) {
    await GlobalState().loadSavedEnvironment();
  }
  // Tag this isolate so diagnostics can tell background from foreground.
  GlobalState().isBackgroundIsolate = true;
  if (_isCleverTapPush(message)) {
    _handleCleverTapPush(message, "BACKGROUND");
  } else {
    _logNotificationReceived(message, "BACKGROUND");

    String? accessToken = await SecureStorageUtils.getAccessToken(
        "BACKGROUND_PUSH_NOTIFICATION_HANDLER");

    if (accessToken != null) {
      await initializeService();
    }

    await loopSound(
      message: message,
      payloadLanguage: message.data['language_preference'] as String?,
    );

    // Handle Auto-OT cancellation in background
    final notificationType = message.data['name'];
    if (notificationType == 'AUTO_OT_CANCELLED') {
      // Store in SharedPreferences to handle when app opens
      await SharedPreferencesAsync().setBool('auto_ot_cancelled_pending', true);
    }

    Response? response = await RunnerHttp.runnerAppCurrentState(isFg: false);
    if (response != null &&
        response.statusCode == 200 &&
        response.data != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
            'cached_current_state', jsonEncode(response.data));
        await prefs.setInt(
            'cached_current_state_ts', DateTime.now().millisecondsSinceEpoch);
        try {
          MonitoringServiceHelper.logInfo(
              'expert_state_sync', {'step': 'bg_fcm_cache_written'});
        } catch (_) {}
      } catch (e, stackTrace) {
        FirebaseCrashlytics.instance.recordError(e, stackTrace,
            reason: 'Background FCM state cache write failed', fatal: false);
      }
    }
  }
}

/// WS5: re-signal the MQTT engine to reconnect/reconcile after a network/doze
/// gap — invoked on foreground FCM and app-resume. Gated to the realtime cohort
/// via [RunnerRtDataProvider.isMqttCohort]; `wake` is idempotent (no engine
/// start if one is already running) and entirely best-effort. The killed/bg
/// path does NOT route through here — that wake is native (WS7).
void wakeRealtimeIfMqttCohort() {
  final ctx = GlobalState().navigatorKey.currentContext;
  if (ctx == null) return;
  try {
    if (Provider.of<RunnerRtDataProvider>(ctx, listen: false).isMqttCohort) {
      RealtimeChannel.wake();
    }
  } catch (e) {
    // Provider not in scope (pre-mount) — skip; the engine's own reconnect
    // covers the gap. Logged (not swallowed) per project convention.
    MonitoringServiceHelper.logDebug(
      'realtime_wake_skipped',
      {'error': e.runtimeType.toString()},
    );
  }
}

/// Push the current app-side MQTT kill-switch (`expert_mqtt_enabled`) + poll
/// cadence to the native engine — but only for mqtt_config-cohort users (others
/// have no engine). Called on live Remote Config updates so a broker-down toggle
/// takes effect mid-session (feature #1); idempotent — the engine no-ops if the
/// mode is unchanged. Fail-open: default MQTT-on when the flag is absent.
void _pushMqttKillSwitchIfCohort() {
  final ctx = GlobalState().navigatorKey.currentContext;
  if (ctx == null) return;
  try {
    if (Provider.of<RunnerRtDataProvider>(ctx, listen: false).isMqttCohort) {
      unawaited(RealtimeChannel.setMqttEnabled(
        RemoteConfigService.instance
            .getBool(RemoteConfigKeys.mqttEnabled, defaultValue: true),
        RemoteConfigService.instance.getNonZeroInt(
          RemoteConfigKeys.currentStatePollInterval,
          defaultValue: 60,
        ),
        RemoteConfigService.instance.getNonZeroInt(
          RemoteConfigKeys.mqttConnectTimeout,
          defaultValue: 25,
        ),
        RemoteConfigService.instance.getNonZeroInt(
          RemoteConfigKeys.mqttPostActionTimeout,
          defaultValue: 5,
        ),
        healthAnalyticsEnabled: RemoteConfigService.instance
            .getBool(RemoteConfigKeys.mqttHealthAnalytics, defaultValue: true),
      ));
    }
  } catch (e) {
    // Provider not in scope (pre-mount) — skip; the cohort-start push already
    // set the flag. Logged (not swallowed) per project convention.
    MonitoringServiceHelper.logDebug(
      'mqtt_killswitch_push_skipped',
      {'error': e.runtimeType.toString()},
    );
  }
}

Future<void> firebaseMessagingForegroundHandler(RemoteMessage message) async {
  if (_isCleverTapPush(message)) {
    _handleCleverTapPush(message, "FOREGROUND");
  } else {
    NotificationService.instance.createNotificationChannel().then((_) async {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;
      _logNotificationReceived(message, "FOREGROUND");
      if (notification != null &&
          android != null &&
          _isFresh(message) &&
          message.data['name'] != 'AWOL_BREACH' &&
          message.data['name'] != 'NOT_GOING_TO_JOB_BREACH' &&
          message.data['name'] != 'DELAYED_CHECKIN_PENALTY' &&
          message.data['name'] != 'AUTO_OT_REQUEST') {
        NotificationService.instance.showNotification(
          id: notification.hashCode,
          title: toBeginningOfSentenceCase(
              notification.title?.replaceAll("_", " ").toLowerCase()),
          body: notification.body,
          payload: jsonEncode(message.data),
        );
      }
    }).then((val) async {
      await loopSound(message: message);

      // WS5: foreground FCM — re-signal the MQTT engine (realtime cohort only).
      wakeRealtimeIfMqttCohort();

      // Handle Auto-OT notifications
      final notificationType = message.data['type'];
      if (notificationType == 'AUTO_OT_CANCELLED') {
        final context = GlobalState().navigatorKey.currentContext;
        if (context != null) {
          try {
            Provider.of<AutoOtProvider>(context, listen: false)
                .handleAutoOtCancellation();
          } catch (e) {
            // Provider might not be available yet
            try {
              MonitoringServiceHelper.logDebug(
                'Error handling Auto-OT cancellation',
                {'error': e.toString()},
              );
            } catch (e) {
              // DO NOTHING
              if (kDebugMode) {
                print('Error handling Auto-OT cancellation: $e');
              }
            }
          }
        }
      }

      // Handle safety shield SOS notification on receive
      if (notificationType == 'safety_shield_sos') {
        try {
          final action = message.data['action'] as String?;
          final sosIdStr = message.data['sos_id'];
          final sosId = sosIdStr is int
              ? sosIdStr
              : int.tryParse(sosIdStr?.toString() ?? '');
          if (action != null && sosId != null) {
            final adapter = GlobalState().shieldAdapter;
            if (adapter != null) {
              await adapter.handleSOSNotification(action: action, sosId: sosId);
            } else {
              // Adapter not ready (pre-mount) — persist for the next reconcile
              // instead of dropping the SoS action.
              await ShieldSosPushStore.persist(action: action, sosId: sosId);
            }
          }
        } catch (_) {}
      }

      // Skip app state refresh for chat notifications - they don't change app state
      if (notificationType != 'customer_chat') {
        fetchAppStateSafely();
      }
    }).catchError((e) async {
      fetchAppStateSafely();
    });
  }
}

Future<void> initNotificationPlugin() async {
  await NotificationService.instance.initialize();
}

void main() {
  runZonedGuarded(() async {
    final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

    // Wire the KMP → Dart crash-report receive side as early as possible
    // so failures during subsequent init (Firebase, RemoteConfig, BCP
    // hydrate) reach Coralogix instead of vanishing.
    KmpCrashReporterBridge.initialize();

    try {
      // Lock to portrait mode to prevent GPU surface recreation on rotation
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    } catch (_) {}
    //? START SPLASH SCREEN
    FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

    // The design-only build must not wait for Firebase, Remote Config,
    // authentication, or any other production service before rendering.
    if (FrontendPreview.enabled) {
      FlutterNativeSplash.remove();
      runApp(const MyApp());
      return;
    }

    // Load saved environment from debug menu (debug mode only)
    if (kDebugMode) {
      await GlobalState().loadSavedEnvironment();
      // Apply persisted Chucker network-inspector notification settings now
      // that the debug prefs are loaded, before runApp/navigator come up.
      await applyChuckerDebugSettings();
      // Bind the native Chucker button's "Flutter (Dio)" action to open chucker_flutter here.
      DebugNetworkInspector.instance.bindNativeBridge();
      // Route Dart/Dio through the device Wi-Fi proxy (Charles/Proxyman) if one is
      // set, so QA can MITM-inspect HTTPS. No-op unless a proxy is configured.
      await installQaProxyIfDebug();
    }
    //! INITIALIZE FIREBASE
    // Initialize Firebase first - required before using Firebase Performance
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize device ID for API headers
    try {
      GlobalState().deviceId = await DeviceIdentifier.getDeviceIdOrEmpty();
    } catch (e) {
      debugPrint('[DeviceIdentifier] Failed to get device ID: $e');
    }

    // Track RemoteConfig initialization (this is the biggest bottleneck)
    // Set user ID in Firebase Crashlytics for crash tracking of persisted logged-in user
    _setUserIdentifierIfPossible();

    // Publish the running build as Firebase Analytics user properties so
    // Remote Config conditions can target app versions. Ordered ahead of the
    // fetch below so it is likely to carry them — a freshly upgraded install
    // otherwise evaluates version conditions against the previous build.
    // Never throws; ~ms of channel hops next to the network fetch that
    // follows, and setLatestVersionCode() below makes the same PackageInfo
    // call unguarded.
    await AnalyticsService.instance.setAppVersionProperties();

    final remoteConfigTrace =
        FirebasePerformance.instance.newTrace('init_remote_config');
    remoteConfigTrace.start();
    await RemoteConfigService.instance.initialize();
    remoteConfigTrace.stop();
    // Mirror the KMP-relevant RC bool flags into the KMP module now that RC is
    // active, and keep it fresh on live config updates (fire-and-forget). KMP's
    // Profile screen gates the Monthly-earnings + Refer&earn tiles on these.
    unawaited(KmpRemoteConfigMirror.push());
    RemoteConfigService.instance.onUpdatedKeys.listen((_) {
      KmpRemoteConfigMirror.push();
      // Feature #1: live app-side MQTT kill-switch flip (broker-down toggle),
      // cohort-gated so only mqtt_config-cohort users (who have an engine) pay it.
      _pushMqttKillSwitchIfCohort();
    });
    // Handle KMP → Flutter Profile actions (e.g. the native Silent-notifications tile).
    ProfileActionsChannel.init();
    // Handle KMP → Flutter new-job alert edges (START/STOP) fired by JobScreenLauncher's
    // store observer over the job_overlay channel — the mqtt cohort's on-open sound trigger.
    JobOverlayChannel.init();
    unawaited(BcpGate.instance.hydrate());

    // Initialize Firebase Performance Monitoring
    // Note: Cold start and hot start are automatically tracked by Firebase Performance
    // We only need to enable collection and create custom traces for specific operations
    try {
      FirebasePerformance.instance.setPerformanceCollectionEnabled(!kDebugMode);
    } catch (_) {}

    unawaited(MonitoringServiceHelper.initializeAllServices());
    await GlobalState().setLatestVersionCode();
    GlobalState().prefs = await SharedPreferences.getInstance();

    // Boot the KMP network module: install the auth-callback listener and
    // push baseUrl + versionCode (+ persisted token if any) so KMP's init
    // gate opens before the first feature request fires.
    try {
      NetworkChannel.onUnauthorized(handle403);
      // A 403 detected inside a background isolate can't touch the KMP auth
      // channel or the navigator (both live on this, the main, FlutterEngine).
      // The background isolate relays it here via notifyMainIsolateForceLogout()
      // and we complete the logout in the foreground.
      FlutterBackgroundService().on('force_logout').listen((_) {
        handle403();
      });
      final kmpToken = await SecureStorageUtils.getAccessToken('KMP_INIT');
      await NetworkChannel.bootstrap(
        baseUrl: GlobalState().remoteUrl,
        versionCode: '${GlobalState().latestVersionCode ?? 0}',
        token: kmpToken,
      );
    } catch (e) {
      debugPrint('[KMP] cold-start init failed: $e');
      // Report so we can spot production cases where KMP-backed requests
      // are silently degraded. The Dart HTTP path still works, so this is
      // not user-blocking — just observability.
      MonitoringServiceHelper.logError(
        'KMP_COLD_START_INIT_FAILED',
        {
          'error': e.toString(),
          'baseUrl': GlobalState().remoteUrl,
          'versionCode': '${GlobalState().latestVersionCode ?? 0}',
        },
      );
    }

    await MixpanelSetup.instance.initialize();

    _registerLaunchSuperProperties();

    // SET ERROR CATCHING

    FlutterError.onError = (errorDetails) {
      // Filter out network image loading errors - these are not fatal crashes
      final exception = errorDetails.exception;
      final isNetworkImageError =
          exception.toString().contains('HttpException') ||
              exception.toString().contains('SocketException') ||
              exception.toString().contains('Connection') ||
              exception.toString().contains('TimeoutException') ||
              exception.toString().contains('HandshakeException') ||
              (errorDetails.library == 'image resource service' ||
                  errorDetails.context?.toString().contains('image') == true);

      // EventChannel teardown race: Flutter swallows the platform 'cancel'
      // PlatformException into FlutterError (never rethrown), so it surfaces
      // here and would be mis-counted as a fatal crash. It's benign — the
      // stream is already gone — so record it non-fatal. Covers every channel
      // (shield + auth/deeplink/overlay/nav), which a per-handler catch cannot.
      final isEventChannelTeardown = exception is PlatformException &&
          exception.message == 'No active stream to cancel';

      if (!isNetworkImageError && !isEventChannelTeardown) {
        FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
        MonitoringServiceHelper.logCriticalError(
          errorDetails.exception.toString(),
          {'stack': errorDetails.stack.toString()},
        );
      } else {
        // Log network / benign framework errors as non-fatal
        FirebaseCrashlytics.instance.recordError(
          errorDetails.exception,
          errorDetails.stack,
          fatal: false,
        );
      }
    };
    // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      MonitoringServiceHelper.reportError(
        error.toString(),
        {},
        stack.toString(),
      );
      return true;
    };

    FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);

    try {
      // Reduce image cache size to lower GPU memory pressure
      // Helps prevent crashes on Android 10 devices with Mali GPUs
      PaintingBinding.instance.imageCache.maximumSize = 100; // Default is 1000
      PaintingBinding.instance.imageCache.maximumSizeBytes =
          50 << 20; // 50MB instead of 100MB
    } catch (e, stackTrace) {
      MonitoringServiceHelper.reportError(
        'Error setting image cache',
        {
          'error': e.toString(),
        },
        stackTrace.toString(),
      );
    }

    logInitialLocationPermissionStatus();
    logInitialNotificationPermissionStatus();

    showLocationPermissionConfirmation();
    showNotificationPermissionConfirmation();

    // Best-effort cleanup of stale capture images from prior sessions.
    // Deferred by 5 s so it runs after splash removal and first-frame
    // rendering — avoids adding file I/O to the hot startup path.
    Future.delayed(const Duration(seconds: 5), _sweepStaleCaptureFiles);

    _initializeShorebird();

    // Initialize Snabbit Shield database and upload queue
    try {
      await ShieldDatabase.instance.initialize();
      final shieldQueue = ShieldUploadQueue(
        db: ShieldDatabase.instance,
      );
      shieldQueue.start();
      GlobalState().shieldUploadQueue = shieldQueue;
    } catch (e) {
      debugPrint('[Shield] DB/queue init failed: $e');
      MonitoringServiceHelper.logError(
        'Snabbit Shield DB/queue init failed',
        {
          'api': 'shield_db_queue_init',
          'error': e.toString(),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    }

    FlutterNativeSplash.remove();
    runApp(const MyApp());
  }, (error, stackTrace) {
    MonitoringServiceHelper.reportError(
      error.toString(),
      {},
      stackTrace.toString(),
    );
  });
}

void _registerLaunchSuperProperties() {
  try {
    // app_version / os_version / device_model are auto-attached by the
    // native Mixpanel SDK ($app_version_string, $os_version, $model) and
    // by CleverTap to every fired event; no need to collect or register
    // them as super properties ourselves.
    OnboardingAnalytics.registerSuperProperties({
      'device_default_language':
          WidgetsBinding.instance.platformDispatcher.locale.toString(),
    });
  } catch (_) {
    // Analytics must never crash the app
  }
}

Future<void> _setUserIdentifierIfPossible() async {
  try {
    String? userId = await SecureStorageUtils.getUserId();
    if (userId != null) {
      await FirebaseCrashlytics.instance.setUserIdentifier(
        userId,
      );
      AnalyticsService.instance.setUserId(userId);
    }
  } catch (_) {}
}

Future<void> _initializeShorebird() async {
  try {
    final shorebirdTrace =
        FirebasePerformance.instance.newTrace('init_shorebird');
    await shorebirdTrace.start();
    ShorebirdManager.instance.initialize();
    await shorebirdTrace.stop();
  } catch (e) {
    MonitoringServiceHelper.logError('init_shorebird_failed', {
      'error': e.toString(),
    });
  }
}

/// Cleans up leftover capture images from prior sessions (e.g. app was
/// killed before [CaptureRegistry] could evict them). Runs best-effort in
/// the background; failures are logged but never block startup.
Future<void> _sweepStaleCaptureFiles() async {
  try {
    final base = await getTemporaryDirectory();
    final capturesDir = Directory('${base.path}/captures');
    // Clear the whole dir: at startup the in-memory registry is empty and no
    // capture is in flight, so every file here is an orphan from a prior
    // session (a kill can leave files the in-session TTL never evicted). A
    // wholesale delete is simpler and more complete than an age scan, and
    // cheap enough to stay off an isolate. Disk hygiene only — `captures/` is
    // app-private sandbox cache.
    await CaptureRegistry.sweepStale(capturesDir);
  } catch (e) {
    // Best-effort — don't block startup; log so a persistent failure is
    // visible rather than silently swallowed.
    MonitoringServiceHelper.logError('capture_startup_sweep_failed', {
      'error': e.toString(),
    });
  }
}

const Duration _newJobLoopMaxDuration = Duration(minutes: 5);

Future<void> loopSound(
    {RemoteMessage? message,
    Response? response,
    bool forceNewJobNotification = false,
    String? payloadLanguage}) async {
  RunnerRtDataProvider? runnerRtProvider;
  OnTheJobStateProvider? onTheJobStateProvider;
  try {
    runnerRtProvider = Provider.of<RunnerRtDataProvider>(
        GlobalState().navigatorKey.currentContext!,
        listen: false);
  } catch (e) {
    // DO NOTHING
  }
  try {
    await GlobalState().audioPlayer.stop();
  } catch (e) {
    Logger().e(e);
  }
  await FileStorage.writeState("playing");
  if (triggerNewJobAllocationNotification(
        message,
        forceNewJobNotification: forceNewJobNotification,
      ) ==
      true) {
    final loopStartedAt = DateTime.now();
    Timer.periodic(1.seconds, (timer) async {
      String state = await FileStorage.readState();
      final cappedOut =
          DateTime.now().difference(loopStartedAt) >= _newJobLoopMaxDuration;
      if (state == 'stopped' || cappedOut) {
        if (cappedOut && state != 'stopped') {
          await FileStorage.writeState('stopped');
          await Vibration.cancel();
          try {
            ClevertapSetup.logEvent(
              TrackingEvents.notificationLoop,
              {
                "state": "CAPPED",
                "is_forced": forceNewJobNotification.toString(),
                "audio_player_state": "${GlobalState().audioPlayer.state}",
              },
            );
          } catch (e) {
            // DO NOTHING
          }
        }
        await GlobalState().audioPlayer.setReleaseMode(ReleaseMode.stop);
        GlobalState().audioPlayer.stop(); // Stop the audio player
        timer.cancel(); // Cancel the timer to prevent further checks
      } else {
        if (triggerNewJobAllocationNotification(
              message,
              forceNewJobNotification: forceNewJobNotification,
            ) ==
            true) {
          setMaxVolume();
          await Vibration.vibrate();
        }
      }
    });
  }

  //  if specific Snabbit app sound is 0 then this doesn't increase the volume
  setMaxVolume();
  // FlutterVolumeController.raiseVolume(1.0);
  try {
    onTheJobStateProvider = Provider.of<OnTheJobStateProvider>(
        GlobalState().navigatorKey.currentContext!,
        listen: false);
  } catch (e) {
    // DO NOTHING
  }

  // Logger().i(message.data['name']);
  try {
    if (triggerNewJobAllocationNotification(message,
            forceNewJobNotification: forceNewJobNotification) !=
        true) {
      await FileStorage.writeState('stopped');
      await Vibration.cancel();
    }
    await GlobalState().audioPlayer.setReleaseMode(ReleaseMode.stop);
  } catch (e) {
    // DO NOTHING
  }

  if (triggerNewJobAllocationNotification(
        message,
        forceNewJobNotification: forceNewJobNotification,
      ) ==
      true) {
    String? fileState;
    try {
      fileState = await FileStorage.readState();
    } catch (e) {
      // DO NOTHING
    }
    try {
      ClevertapSetup.logEvent(
        TrackingEvents.notificationLoop,
        {
          "state": "START",
          "is_forced": forceNewJobNotification.toString(),
          "audio_player_state": "${GlobalState().audioPlayer.state}",
          "file_state": fileState,
        },
      );
    } catch (e) {
      // DO NOTHING
    }
    await Vibration.vibrate();
    const androidContext = AudioContextAndroid(
      isSpeakerphoneOn: true,
      stayAwake: true,
      contentType: AndroidContentType.sonification,
      // Use sonification for notifications
      usageType: AndroidUsageType.alarm,
      audioFocus: AndroidAudioFocus.gain,
    );
    await LocalizedAudioService.playJobAcceptance(
      volume: desiredVolume,
      nudgeCount: message?.data['nudge_count']?.toString(),
      ctx: AudioContext(android: androidContext),
      payloadLanguage: payloadLanguage,
    );
    try {
      ClevertapSetup.logEvent(
        TrackingEvents.notificationLoop,
        {
          "state": "SUCCESS",
          "is_forced": forceNewJobNotification.toString(),
          "audio_player_state": "${GlobalState().audioPlayer.state}",
          "file_state": fileState,
        },
      );
    } catch (e) {
      // DO NOTHING
    }
  } else if (message?.data['name'] == "CANCELLED_JOB") {
    await Vibration.vibrate();
    GlobalState().audioPlayer.play(
        AssetSource("job_cancelled_notification.mp3"),
        volume: desiredVolume);
  } else if (message?.data['name'] == "JOB_IP_THRESHOLD_1") {
    if (triggerJobIpNotification(
            runnerRtProvider, response, onTheJobStateProvider) ==
        true) {
      await Vibration.vibrate(duration: 2000);
      await GlobalState().audioPlayer.play(
          AssetSource("notification_sounds/job_ip_t1.mp3"),
          volume: desiredVolume);
    }
  } else if (message?.data['name'] == "JOB_IP_THRESHOLD_2") {
    if (triggerJobIpNotification(
            runnerRtProvider, response, onTheJobStateProvider) ==
        true) {
      await Vibration.vibrate(duration: 2000);
      await GlobalState().audioPlayer.play(
          AssetSource("notification_sounds/job_ip_t1.mp3"),
          volume: desiredVolume);
    }
    // _stopAudio();
  } else if (message?.data['name'] == "JOB_IP_THRESHOLD_3") {
    if (triggerJobIpNotification(
            runnerRtProvider, response, onTheJobStateProvider) ==
        true) {
      await Vibration.vibrate(duration: 4000);
      await GlobalState().audioPlayer.play(
          AssetSource("notification_sounds/job_ip_t2.mp3"),
          volume: desiredVolume);
    }
  } else if (message?.data['name'] == "JOB_IP_THRESHOLD_4") {
    if (triggerJobIpNotification(
            runnerRtProvider, response, onTheJobStateProvider) ==
        true) {
      await Vibration.vibrate(duration: 8000);
      await GlobalState().audioPlayer.play(
          AssetSource("notification_sounds/job_ip_t3.mp3"),
          volume: desiredVolume);
    }
  } else if (message?.data['name'] == AppStrings.runnerArrived) {
    await Vibration.vibrate(duration: 6000);
    int timesPlayed = 0;
    while (timesPlayed < 3) {
      await GlobalState().audioPlayer.play(
          AssetSource("notification_sounds/3beeps-108353.mp3"),
          volume: desiredVolume);
      //to complete playing of sound
      await Future.delayed(const Duration(milliseconds: 1000));
      timesPlayed++;
    }
  } else if (message?.data['name'] == 'AWOL_BREACH') {
    // Shared with the state-transition path in RunnerRtDataProvider; the
    // service de-dupes so a breach that arrives as BOTH a named push and a
    // stored-state transition never alarms twice.
    await AwolAlarmService.playAlarm(
      AwolState.breach,
      eventId: message?.data['event_id']?.toString(),
    );
  } else if (message?.data['name'] == 'NOT_GOING_TO_JOB_BREACH') {
    await Vibration.vibrate(duration: 2000);
    final prefs = await SharedPreferences.getInstance();
    final repeat = prefs.getInt(AppStrings.expertNotMovingRepeatCountKey) ?? 1;
    await LocalizedAudioService.playExpertNotMoving(
      volume: desiredVolume,
      times: repeat,
      payloadLanguage: payloadLanguage,
    );
  } else if (message?.data['name'] == 'DELAYED_CHECKIN_PENALTY') {
    await Vibration.vibrate(duration: 2000);
    await LocalizedAudioService.playExpertNotMoving(
      volume: desiredVolume,
      payloadLanguage: message?.data['language'] as String?,
    );
  } else if (message?.data['name'] == 'AWOL_JOB') {
    await AwolAlarmService.playAlarm(
      AwolState.job,
      eventId: message?.data['event_id']?.toString(),
    );
  } else if (message?.data['name'] == AppStrings.autoCheckout.toUpperCase()) {
    try {
      await Vibration.vibrate(duration: 3000);
      // ECPO-982: localized auto-checkout cue, suppressed for durations in the RC exclusion list.
      final durationMins =
          await _autoCheckoutJobDurationMinutes(message, runnerRtProvider);
      if (!_autoCheckoutAudioSuppressed(durationMins)) {
        // Isolated so a missing-clip play failure (e.g. an un-shipped localized asset) can't skip the
        // checkout warning below — the warning is the load-bearing UX, the sound is best-effort.
        try {
          final audioLanguage = await LocalizedAudioService.playAutoCheckout(
            payloadLanguage: payloadLanguage,
            volume: desiredVolume,
          );
          // CleverTap/Mixpanel work only on the main isolate — the FCM background isolate has no
          // analytics MethodChannel, so skip the (silently-failing) call there.
          if (!GlobalState().isBackgroundIsolate) {
            await ClevertapSetup.logEvent(
                TrackingEvents.jobInProgressAudioPlayed, {
              'cue': 'auto_checkout',
              'audio_language': audioLanguage,
              'job_duration_minutes': durationMins,
            });
          }
        } catch (e, st) {
          FirebaseCrashlytics.instance.recordError(e, st,
              reason: 'auto-checkout audio/analytics failed', fatal: false);
        }
      }
      if (onTheJobStateProvider?.checkoutForRunnerJobId != null) {
        showCheckoutWarning(GlobalState().navigatorKey.currentContext!, {
          AppStrings.autoCheckout: true,
          AppStrings.jobId: onTheJobStateProvider?.checkoutForRunnerJobId
        });
      }
    } catch (e, st) {
      FirebaseCrashlytics.instance.recordError(e, st,
          reason: 'auto-checkout cue handling failed', fatal: false);
    }
  } else if (message?.data['name'] ==
      AppStrings.customerCheckout.toUpperCase()) {
    try {
      await Vibration.vibrate(duration: 3000);
      await GlobalState().audioPlayer.play(
          AssetSource("notification_sounds/job_ip_t2.mp3"),
          volume: desiredVolume);
    } catch (_) {}
  } else if (message?.data['name'] != null &&
      message?.data['name'].toUpperCase() ==
          AppStrings.autoLogin.toUpperCase()) {
    try {
      await Vibration.vibrate(duration: 3000);
      await GlobalState().audioPlayer.play(
          AssetSource("notification_sounds/job_ip_t3.mp3"),
          volume: desiredVolume);
    } catch (_) {}
  } else if (message?.data['name'] != null &&
      message?.data['name'].toUpperCase() == 'AUTO_OT_REQUEST') {
    try {
      try {
        if (GlobalState().navigatorKey.currentContext != null &&
            GlobalState()
                .navigatorKey
                .currentContext!
                .read<AutoOtProvider>()
                .isPopupVisible) {
          // Avoid overlapping Auto-OT and Auto-Login sounds
          return;
        }
      } catch (e, stackTrace) {
        try {
          await MonitoringServiceHelper.logError(
            'AUTO_OT_SOUND_PLAYBACK_CHECK_FAILED',
            {
              'error': e.toString(),
              'stack_trace': stackTrace.toString(),
              'payload_language': payloadLanguage,
            },
          );
        } catch (_) {}
        // Fail closed: if the popup-visibility check throws we can't confirm
        // whether an Auto-Login sound is already playing, so skip playback
        // to avoid overlapping Auto-OT and Auto-Login sounds.
        return;
      }
      await Vibration.vibrate(duration: 3000);
      await LocalizedAudioService.playAutoOtRequest(
        volume: desiredVolume,
        payloadLanguage: payloadLanguage,
      );
    } catch (e, stackTrace) {
      try {
        await MonitoringServiceHelper.logError(
          'AUTO_OT_SOUND_PLAYBACK_FAILED',
          {
            'error': e.toString(),
            'stack_trace': stackTrace.toString(),
            'payload_language': payloadLanguage,
          },
        );
      } catch (_) {}
    }
  } else if (message?.data['name']?.toUpperCase() == 'CHAT_NOTIFICATION') {
    try {
      await Vibration.vibrate(duration: 1000);
      await GlobalState().audioPlayer.play(
          AssetSource("notification_sounds/chat_message.mp3"),
          volume: desiredVolume);
    } catch (_) {}
  } else {
    await Vibration.vibrate();
    await GlobalState()
        .audioPlayer
        .play(AssetSource("custom_sound.wav"), volume: desiredVolume);
  }
}

/// Current in-progress job duration (minutes) for the auto-checkout cue (ECPO-982) — from the push
/// payload (works in the killed isolate), the RT provider (foreground), or the cached `current_state`.
Future<int?> _autoCheckoutJobDurationMinutes(
    RemoteMessage? message, RunnerRtDataProvider? runnerRtProvider) async {
  return anyValueToInt(message?.data['duration']) ??
      anyValueToInt(runnerRtProvider?.widgetInfo?.data?['duration']) ??
      await _cachedJobDurationMinutes();
}

/// True when the AUTO_CHECKOUT voice cue should be SUPPRESSED for the current job — i.e.
/// [durationMinutes] is in the `expert_job_audio_auto_checkout_excluded_durations` RC list (ECPO-982).
/// Fail-open: an unknown duration, an empty/absent list, or any parse error ⇒ not suppressed (the cue
/// plays), preserving the pre-ECPO-982 always-play behaviour.
bool _autoCheckoutAudioSuppressed(int? durationMinutes) {
  try {
    if (durationMinutes == null) return false;
    // Parse the raw string tolerantly (strip brackets/whitespace, split on commas) so a JSON array
    // `[30,45]` and a bare CSV `30,45` both work — matching the KMP JobAudioCueScheduler.parseDurations,
    // so all three cues treat the same RC value identically.
    final raw = RemoteConfigService.instance.getString(
      RemoteConfigKeys.jobAudioAutoCheckoutExcludedDurations,
      defaultValue: '[]',
    );
    final excluded = raw
        .replaceAll(RegExp(r'[\[\]\s]'), '')
        .split(',')
        .map(int.tryParse)
        .whereType<int>()
        .toSet();
    return excluded.contains(durationMinutes);
  } catch (e, st) {
    FirebaseCrashlytics.instance.recordError(e, st,
        reason: 'auto-checkout audio suppression check failed', fatal: false);
    return false;
  }
}

/// Best-effort current-job duration (minutes) from the persisted `current_state` envelope — the only
/// source in the killed/background FCM isolate, where `RunnerRtDataProvider` is null. Reads
/// `SharedPreferences` directly rather than `GlobalState().prefs`, which is only assigned in `main()`
/// and is therefore null in the separate background isolate — the exact case this fallback exists for.
/// Only trusts the cache while it is fresh (`cached_current_state_ts` within `expert_bg_cache_max_age_ms`,
/// 30s default) — mirrors `RunnerRtDataProvider.applyCachedStateIfFresh`, so a stale previous-job
/// envelope can't feed the wrong duration. Returns null on any miss/parse error.
Future<int?> _cachedJobDurationMinutes() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final cachedTs = prefs.getInt('cached_current_state_ts') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final maxAgeMs = RemoteConfigService.instance.getInt(
      'expert_bg_cache_max_age_ms',
      defaultValue: 30000,
    );
    if (now - cachedTs >= (maxAgeMs > 0 ? maxAgeMs : 30000)) return null;
    final raw = prefs.getString('cached_current_state');
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    final widgetData = decoded['widget_data'];
    if (widgetData is! Map) return null;
    return anyValueToInt(widgetData['duration']);
  } catch (e, st) {
    FirebaseCrashlytics.instance.recordError(e, st,
        reason: 'cached job duration read failed', fatal: false);
    return null;
  }
}

bool? triggerJobIpNotification(RunnerRtDataProvider? runnerRtProvider,
    Response? response, OnTheJobStateProvider? onTheJobStateProvider) {
  try {
    return (runnerRtProvider?.widgetInfo?.name == 'RUNNER_JOB_IN_PROGRESS' ||
            response?.data['widget_name'] == 'RUNNER_JOB_IN_PROGRESS') &&
        (onTheJobStateProvider == null ||
            onTheJobStateProvider.currentState == OnTheJobState.onTheJob);
  } catch (e) {
    return null;
  }
}

bool? triggerNewJobAllocationNotification(RemoteMessage? notificationName,
    {bool? forceNewJobNotification}) {
  if (forceNewJobNotification == true) {
    return true;
  }
  try {
    return isJobAllocationNew(notificationName) == true;
  } catch (e) {
    return null;
  }
}

bool? isJobAllocationNew(RemoteMessage? message) {
  try {
    return message?.data['name'] == "NEW_JOB_ALLOCATION";
  } catch (e) {
    return null;
  }
}

Future<void> fetchAppStateSafely() async {
  try {
    await Provider.of<RunnerRtDataProvider>(
            GlobalState().navigatorKey.currentContext!,
            listen: false)
        .fetchDataNow();
  } catch (_) {
    await RunnerHttp.runnerAppCurrentState();
  }
}

// void onDidReceiveBackgroundNotificationResponse(
//     NotificationResponse? nr) async {}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  try {
    final hasMic = await _ensureMicPermissionForBackgroundService();
    if (!hasMic) {
      // Do not start foreground service without microphone permission to avoid
      // ForegroundServiceDidNotStartInTimeException on Android 14+.
      // This silently blocks the bg location service (and ALL IoT collection)
      // from starting, so emit a diagnostic to size how many runners are blocked
      // by mic denial vs. other causes. Flushed on the next foreground.
      try {
        await IotDiagnosticsCollector().logDiagnostic(
          'IOT_BG_SERVICE_SKIPPED_NO_MIC',
          {'reason': 'mic_permission_not_granted'},
        );
      } catch (_) {}
      return;
    }

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: startBgLocService,
        autoStart: true,
        autoStartOnBoot: true,
        isForegroundMode: true,
        initialNotificationTitle: 'Location Service',
        initialNotificationContent: 'Initializing',
        foregroundServiceNotificationId: 999,
        foregroundServiceTypes: [
          AndroidForegroundType.location,
          AndroidForegroundType.microphone
        ],
      ),
      iosConfiguration: IosConfiguration(),
    );

    service.startService();
  } catch (e) {
    // Catch and log background service errors instead of crashing
    FirebaseCrashlytics.instance.recordError(
      e,
      StackTrace.current,
      reason: 'Background service initialization failed',
      fatal: false,
    );
  }
}

void stopService() {
  _isBGServiceRunning = false;
  if (GlobalState().isBackgroundIsolate) {
    // Inside a background isolate the main-isolate FlutterBackgroundService
    // channel isn't registered, so `invoke("stopService")` would throw
    // MissingPluginException. Stop via the captured ServiceInstance instead
    // (null in isolates that never started the loc service, e.g. the FCM
    // handler — a safe no-op there).
    _bgServiceInstance?.stopSelf();
    return;
  }
  final service = FlutterBackgroundService();
  service.invoke("stopService");
}

/// Relays a background-detected force-logout (a 403 seen while running in a
/// background isolate) to the main isolate.
///
/// The KMP auth MethodChannel (`AuthPlugin`) and the navigator both live on
/// the main FlutterEngine, so a background isolate cannot clear the KMP token
/// or redirect on its own. It hands the work over the background-service
/// bridge: `ServiceInstance.invoke` reaches the main isolate's
/// `FlutterBackgroundService().on('force_logout')` listener (wired in
/// `main()`), which then runs `handle403` in the foreground.
///
/// No-op when no ServiceInstance is available (e.g. the FCM background
/// isolate); the shared secure-storage clear in `handle403` still applies, and
/// the main isolate self-heals on its next 401 via the auth-events stream.
void notifyMainIsolateForceLogout() {
  _bgServiceInstance?.invoke('force_logout');
}

/// Run IoT jobs asynchronously without blocking the main background service
Future<void> _runIotJobsAsync(SharedPreferences prefs, dynamic response) async {
  try {
    // Extract user_id from response if available
    // For now, we'll get it from SharedPreferences if stored during login
    final userId = prefs.getString('user_id');

    if (userId != null && userId.isNotEmpty) {
      // Get runner status from response data
      String runnerStatus = 'available';
      if (response != null && response.data != null && response.data is Map) {
        final data = response.data as Map<String, dynamic>;
        runnerStatus = data['runner_status'] ?? 'available';
      }

      // Get IoT endpoint and run jobs
      final iotEndpoint = GlobalState().atlasServerPath('api/v1/iot');
      await _iotManager!.runPeriodicJobs(
        userId: userId,
        runnerStatus: runnerStatus,
        iotEndpoint: iotEndpoint,
      );
    }
  } catch (e) {
    debugPrint('[IoT] Background job error: $e');
  }
}

/// Whether the background location isolate should SKIP its own `current_state`
/// poll for this runner. True for the `mqtt_config` cohort, whose `current_state`
/// is already owned by the KMP `/realtime` engine (MQTT + its own poll fallback →
/// Room) — the Dart background poll is a duplicate. RC-reversible via
/// [RemoteConfigKeys.enableMqttCohortBgCurrentStateSkip] (default-ON); set false
/// to fall back to the legacy always-poll behaviour without a binary push.
///
/// IoT location jobs are unaffected — they run regardless; only `runner_status`
/// (a diagnostic tag; every status maps to the same 60s location interval) falls
/// back to its cached/default value for the cohort. Reads the cohort flag fresh
/// ([MqttCohortCache.isCohortFresh]) because this runs in the background isolate,
/// whose SharedPreferences snapshot is otherwise stale to a main-isolate write.
Future<bool> _skipBgCurrentStateForMqttCohort() async {
  final enabled = RemoteConfigService.instance.getBool(
    RemoteConfigKeys.enableMqttCohortBgCurrentStateSkip,
    defaultValue: true,
  );
  if (!enabled) return false;
  return MqttCohortCache.isCohortFresh();
}

@pragma('vm:entry-point')
void startBgLocService(ServiceInstance service) async {
  if (_isBGServiceRunning) {
    debugPrint("Service already running, preventing duplicate start");
    return;
  }
  _isBGServiceRunning = true;
  // Capture the ServiceInstance so isolate-local code (e.g. handle403 on a
  // background 403) can stop the service and relay to the main isolate without
  // the main-isolate-only FlutterBackgroundService channel.
  _bgServiceInstance = service;

  DartPluginRegistrant.ensureInitialized();

  // GlobalState is per-isolate; this background-service isolate started with
  // a fresh singleton (currentEnv = prodEnv). Mirror the foreground main() so
  // any debug-menu env / overrides set by the user are honoured here too,
  // otherwise CUSTOM-env testers see API calls fired against prod URLs.
  // kDebugMode-gated to match the foreground load — a stale debug-menu env
  // pref must never redirect a release build's background API calls.
  if (kDebugMode) {
    await GlobalState().loadSavedEnvironment();
  }
  // Tag this isolate so diagnostics can tell background from foreground.
  GlobalState().isBackgroundIsolate = true;

  if (service is AndroidServiceInstance) {
    // Set as foreground service immediately to prevent ForegroundServiceDidNotStartInTimeException
    // This must be called within 5 seconds of startForegroundService()
    try {
      await service.setAsForegroundService();
    } catch (e) {
      debugPrint("Error setting foreground service: $e");
      // Continue anyway to prevent crash
    }

    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }
  service.on('stopService').listen((event) {
    _isBGServiceRunning = false;
    _bgServiceInstance = null;
    service.stopSelf();
    MonitoringServiceHelper.logInfo('BG_SERVICE_STOPPED', {
      'iot_manager_active': _iotManager != null,
      'timestamp': DateTime.now().toIso8601String(),
    });
  });

  // Listen for IoT config updates from the main isolate
  service.on('iot_config_updated').listen((event) async {
    // Reload SharedPreferences to get the latest config
    final freshPrefs = await SharedPreferences.getInstance();
    await freshPrefs.reload();

    // Refresh ConfigService's in-memory cache with all updated values
    await ConfigService.instance.refresh();

    // Use ConfigService's cached value (just refreshed from SharedPreferences)
    final iotEnabled = ConfigService.instance.apiEnabled;

    if (iotEnabled && _iotManager == null) {
      // IoT was disabled, now enabled - initialize manager
      _iotManager = IotBackgroundManager();
      try {
        await _iotManager!.initialize();
      } catch (e) {
        FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
            reason: 'IoT config update init failed', fatal: false);
        _iotManager = null;
      }
    } else if (!iotEnabled && _iotManager != null) {
      // IoT was enabled, now disabled - dispose manager
      _iotManager = null;
    }
  });

  // Initialize Firebase in background isolate for Crashlytics error reporting
  // Must be after service listeners are registered to avoid MissingPluginException
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    debugPrint('[BG Service] Firebase init failed: $e');
  }

  final prefs = await SharedPreferences.getInstance();

  // Mark this background-service start: a fresh session id + an incremented
  // restart counter let us see kill/restart churn (a killed isolate can't
  // report its own death, but a jump in bg_restart_count between a device's
  // diagnostics reveals it).
  final bgRestartCount = (prefs.getInt('iot_bg_restart_count') ?? 0) + 1;
  await prefs.setInt('iot_bg_restart_count', bgRestartCount);
  IotDiagnosticsCollector.bgBootSessionId =
      'bg-${DateTime.now().millisecondsSinceEpoch}';
  IotDiagnosticsCollector.bgRestartCount = bgRestartCount;

  // Check if IoT is enabled before initializing
  final iotEnabled = prefs.getBool('iot_config_api_enabled') ?? false;

  if (iotEnabled) {
    // Initialize IoT manager only if enabled
    _iotManager = IotBackgroundManager();
    try {
      await _iotManager!.initialize();
    } catch (e) {
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
          reason: 'IoT initialization failed', fatal: false);
      _iotManager = null;
    }
  } else {
    _iotManager = null;
  }

  // True if IoT is enabled and successfully initialized
  final isIotActive = _iotManager != null;

  // Read the skip flag from config (synced from Firebase Remote Config)
  final skipIotConfigFlag =
      prefs.getBool('iot_config_skip_location_battery_in_runner_state') ?? true;

  // Combine both: skip location/battery only if IoT is active AND config allows it
  final shouldSkipIotWithRunnerState = isIotActive && skipIotConfigFlag;

  // Skip location/battery in this call if IoT is handling it. The mqtt_config
  // cohort skips the call entirely — the KMP /realtime engine owns current_state.
  if (!await _skipBgCurrentStateForMqttCohort()) {
    await RunnerHttp.runnerAppCurrentState(
        isFg: false, skipIotWithRunnerState: shouldSkipIotWithRunnerState);
  }

  Timer.periodic(const Duration(seconds: 10), (timer) async {
    // Write heartbeat so the main isolate can detect if the service was killed
    prefs.setInt(
        'iot_bg_service_heartbeat', DateTime.now().millisecondsSinceEpoch);

    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        service.setForegroundNotificationInfo(
          title: "Snabbit Expert",
          content: "Location Service Activated",
        );
      }
    }

    if (_isBGPostRequestInProgress) {
      debugPrint("Previous request still in progress, skipping");
      return;
    }

    final lastUpdateTime = prefs.getInt('lastUpdateTime') ?? 0;
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    final timeDifference = currentTime - lastUpdateTime;
    final currentStateLastUpdateTime =
        prefs.getInt("current_state_last_update_time") ?? 0;
    final currentStateTimeDifference = currentTime - currentStateLastUpdateTime;

    // More strict timing check
    if (timeDifference >= 5 * 1000) {
      try {
        _isBGPostRequestInProgress = true;
        debugPrint(
            "BACKGROUND LOCATION SERVICE RUNNING - Time since last update: ${timeDifference / 1000}s");

        Response? response;
        final currentStateInterval = RemoteConfigService.instance.getNonZeroInt(
          RemoteConfigKeys.currentStatePollInterval,
          defaultValue: 60,
        );
        // Skip location/battery in recurring call if IoT is handling it
        if (currentStateTimeDifference >= currentStateInterval * 1000) {
          // The mqtt_config cohort's current_state is owned by the KMP /realtime
          // engine (MQTT + its own poll fallback → Room); skip the redundant Dart
          // background fetch for them. Still stamp the timestamp below so the
          // cohort check runs on the poll cadence, not every 10s tick.
          if (!await _skipBgCurrentStateForMqttCohort()) {
            // Refresh every 60 seconds to ensure sync
            response = await RunnerHttp.runnerAppCurrentState(
                isFg: false,
                skipIotWithRunnerState: shouldSkipIotWithRunnerState);
            try {
              if (response != null && response.statusCode == 200) {
                prefs.setString(
                    "current_state_response", jsonEncode(response.data));
              } else {
                prefs.setString("current_state_response", '');
              }
            } catch (_) {}
          }
          prefs.setInt("current_state_last_update_time",
              DateTime.now().millisecondsSinceEpoch);
        }

        if (response == null) {
          try {
            final data =
                jsonDecode(prefs.getString("current_state_response") ?? '');
            response = Response(
              requestOptions: RequestOptions(),
              data: data,
              statusCode: 200,
            );
          } catch (_) {}
        }

        // Self-healing: if IoT manager is null but config says enabled, try to resurrect
        if (_iotManager == null) {
          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - _lastIotResurrectionAttempt >= 60 * 1000) {
            _lastIotResurrectionAttempt = now;
            try {
              await prefs.reload();
              final iotEnabled =
                  prefs.getBool('iot_config_api_enabled') ?? false;
              if (iotEnabled) {
                debugPrint(
                    '[IoT] Resurrecting IoT manager — was null but config is enabled');
                _iotManager = IotBackgroundManager();
                await _iotManager!.initialize();
                FirebaseCrashlytics.instance.log('IoT manager resurrected');
                MonitoringServiceHelper.logDebug(
                  "IOT_MANAGER_RESURRECTED",
                  {},
                );
              }
            } catch (e, st) {
              debugPrint('[IoT] Resurrection failed: $e');
              FirebaseCrashlytics.instance.recordError(
                e,
                StackTrace.current,
                reason: 'IoT manager resurrection failed',
                fatal: false,
              );
              _iotManager = null;
              MonitoringServiceHelper.logError(
                "IOT_RESURRECTION_FAILED",
                {
                  "error": e.toString(),
                  "stacktrace": st.toString(),
                },
              );
            }
          }
        }

        // Run IoT periodic jobs (non-blocking, fire-and-forget)
        if (_iotManager != null) {
          SharedPreferences.getInstance().then((freshPrefs) async {
            await freshPrefs.reload();
            _runIotJobsAsync(freshPrefs, response);
          });
        }

        // Update timestamp only after successful request
        await prefs.setInt(
            'lastUpdateTime', DateTime.now().millisecondsSinceEpoch);
      } catch (e) {
        debugPrint("Error getting location or sending to backend: $e");
      } finally {
        _isBGPostRequestInProgress = false;
      }
    } else {
      debugPrint(
          "Skipping update - Too soon (${timeDifference / 1000}s since last update)");
    }
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  String? accessToken;
  bool loading = true;
  Widget? initialScreen;

  /// Periodically flushes queued IoT diagnostics while the app is foreground,
  /// so they don't wait for the next background→foreground transition.
  Timer? _diagnosticsFlushTimer;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Persist foreground/background so the bg-service isolate can stamp is_fg
    // on its diagnostics at emit time (robust to deferred-flush timestamps).
    IotDiagnosticsCollector.persistLifecycle(
        state == AppLifecycleState.resumed);

    // Process queue when app comes back to foreground
    if (state == AppLifecycleState.resumed) {
      RootDetectionService.performRootCheck();
      // print("App resumed - checking notification queue...");
      showNotificationPermissionConfirmation();
      showLocationPermissionConfirmation();

      // Flush queued IoT diagnostic events to analytics services
      IotDiagnosticsReporter().flushDiagnostics();

      // Check if background service is still alive via heartbeat
      _checkBgServiceHeartbeat();

      // Check for pending Auto-OT cancellation
      _checkPendingAutoOtCancellation();

      // WS5: app resumed — re-signal the MQTT engine to reconnect/reconcile
      // after a doze/network gap (realtime cohort only; idempotent).
      wakeRealtimeIfMqttCohort();

      // Re-report the FCM token + running build if the last successful report
      // doesn't cover this build. Login is otherwise the only trigger, so a
      // transient Play Services failure there used to cost the whole session
      // (and an upgrade never re-reported). No-op after the first success —
      // one SharedPreferences read, no getToken, no network.
      unawaited(SelectLanguageInitProvider.ensureFcmReported());

      // Language: reconcile a KMP language change whose live apply couldn't land
      // while the Flutter engine was backgrounded behind the Compose host. Reads
      // the natively-persisted pending code and reloads i18n if needed. Gated by
      // the same RC kill-switch as the CMP language screen (only that screen
      // produces a pending write) — off ⇒ skip the prefs read entirely.
      if (RemoteConfigService.instance
          .getBool(RemoteConfigKeys.cmpLanguageScreenEnabled)) {
        LanguageChannel.reconcilePendingLanguage();
      }
    } else if (state == AppLifecycleState.paused) {
      // Flush before backgrounding so the foreground session's diagnostics
      // ship now instead of waiting for the next resume transition.
      IotDiagnosticsReporter().flushDiagnostics();
    }
  }

  /// Checks if the background service is still alive by reading its heartbeat.
  /// If stale (>2 minutes), the OS likely killed it — restart and log.
  Future<void> _checkBgServiceHeartbeat() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final lastHeartbeat = prefs.getInt('iot_bg_service_heartbeat') ?? 0;
      if (lastHeartbeat == 0) return;

      final now = DateTime.now().millisecondsSinceEpoch;
      final staleness = now - lastHeartbeat;

      if (staleness > 2 * 60 * 1000) {
        final stalenessSeconds = staleness ~/ 1000;
        MonitoringServiceHelper.logWarning('IOT_BG_SERVICE_STALE_HEARTBEAT', {
          'staleness_seconds': stalenessSeconds,
          'last_heartbeat': lastHeartbeat,
        });

        MixpanelSetup.logEvent('IOT_BG_SERVICE_STALE_HEARTBEAT', {
          'staleness_seconds': stalenessSeconds,
        });

        // Attempt to restart the background service
        final service = FlutterBackgroundService();
        final isRunning = await service.isRunning();
        if (!isRunning) {
          MonitoringServiceHelper.logWarning('IOT_BG_SERVICE_RESTARTING', {
            'staleness_seconds': stalenessSeconds,
          });
          initializeService();
        }
      }
    } catch (e, st) {
      MonitoringServiceHelper.logError(
        "IOT_BG_SERVICE_HEARTBEAT_FAILED",
        {
          "error": e.toString(),
          "stacktrace": st.toString(),
        },
      );
    }
  }

  /// Checks for pending Auto-OT cancellation from background
  Future<void> _checkPendingAutoOtCancellation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasPendingCancellation =
          prefs.getBool('auto_ot_cancelled_pending') ?? false;

      if (hasPendingCancellation) {
        // Clear the flag
        await prefs.setBool('auto_ot_cancelled_pending', false);

        // Handle cancellation
        final context = GlobalState().navigatorKey.currentContext;
        if (context != null) {
          try {
            Provider.of<AutoOtProvider>(context, listen: false)
                .handleAutoOtCancellation();
          } catch (e) {
            // Provider might not be available yet
          }
        }
      }
    } catch (e) {
      // Ignore errors
    }
  }

  //? to be in splash screen, so we can do all the heavy lifting here before showing the actual app
  Future<void> getUser() async {
    // Track getUser() method (Firebase should be initialized by now)
    Trace? getUserTrace;
    Trace? appConfigTrace;

    try {
      getUserTrace = FirebasePerformance.instance.newTrace('get_user');
      getUserTrace.start();
    } catch (_) {}

    accessToken =
        await SecureStorageUtils.getAccessToken("MY_APP_GET_USER_METHOD");

    //TODO: use app config
    // Track app config fetch (network call)
    try {
      appConfigTrace =
          FirebasePerformance.instance.newTrace('get_user_app_config');
      appConfigTrace.start();
    } catch (_) {}
    await GlobalState().setAppConfig();
    appConfigTrace?.stop();

    getUserTrace?.stop();
    // registrationCompleted = prefs.getBool('registration_completed');
    Logger().i("accessTOKEN $accessToken");
    if (accessToken != null) {
      // if (registrationCompleted != null) {
      //   if (registrationCompleted == true) {
      //     initialScreen = const PartnerHome();
      //   }
      // } else {
      initialScreen = const SelectLanguageV2();
      // }
    } else {
      initialScreen = const GettingStarted();
    }
  }

  // checkIfBGLocationServiceIsEnabled() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   if (prefs.getBool(AppStrings.isBGLocationServiceEnabled) != null) {
  //     if (prefs.getBool(AppStrings.isBGLocationServiceEnabled) == false) {
  //       final service = FlutterBackgroundService();
  //       service.invoke("stopService");
  //     }
  //   } else if (prefs.getBool(AppStrings.isBGLocationServiceEnabled) == null) {
  //     final service = FlutterBackgroundService();
  //     service.invoke("stopService");
  //   }
  // }

  @override
  void initState() {
    super.initState();

    if (FrontendPreview.enabled) {
      loading = false;
      initialScreen = const FrontendPreviewHome();
      return;
    }

    WidgetsBinding.instance.addObserver(this);
    // Seed foreground state at startup — didChangeAppLifecycleState only fires
    // on transitions, so without this the bg isolate would read last session's
    // persisted is_fg until the first background→foreground round-trip.
    IotDiagnosticsCollector.persistLifecycle(true);

    getUser().then((_) {
      loading = false;
      if (mounted) {
        setState(() {});
      }
    });

    // Set up notification tap handlers
    _setupNotificationTapHandlers();

    // Periodically flush queued IoT diagnostics while foreground (the OS
    // suspends this timer in the background, which is fine — the resume/pause
    // handlers cover transitions).
    _diagnosticsFlushTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => IotDiagnosticsReporter().flushDiagnostics(),
    );
  }

  /// Sets up handlers for notification taps (background/killed state)
  void _setupNotificationTapHandlers() {
    // setupFCMTapHandlers's getNotificationAppLaunchDetails() block also
    // covers CleverTap killed-state taps now — since PR B self-renders all
    // CleverTap pushes via flutter_local_notifications, the launch payload
    // surfaces through the same path. No separate CleverTap pull needed.
    NotificationService.instance.setupFCMTapHandlers();
    // AppsFlyer OneLink (UDL) → router (warm stream + cold-start drain). Gated
    // by the enableDeeplinks RC flag inside the router.
    // KMP navigation bridge: subscribe to native → Flutter commands FIRST — the
    // EventChannel does not buffer events emitted before a listener attaches.
    KmpNavigationBridge.instance.start();
    // When the native root-shell host resumes it asks Dart to drain any deeplink held
    // for the cohort, so the linked screen opens ON TOP of the now-foreground shell.
    // allowRequeue: if the shell isn't foreground yet at this drain, re-queue and retry
    // on the next onResume (never consume the link until the handoff actually lands).
    KmpNavigationBridge.instance.onDrainRequested =
        () => DeepLinkRouter.instance.drainPending(allowRequeue: true);
    // Install the Language screen's native -> Dart callback handler eagerly so
    // applyLanguage / trackLanguageEvent work regardless of which entry opens the
    // screen (Flutter drawer OR KMP Profile-tab nav). Without this, the Profile-tab
    // entry has no Dart listener and native's applyLanguage invoke times out (15s).
    LanguageChannel.ensureNativeCallHandler();
    DeepLinkRouter.instance.initOneLink();
  }

  @override
  void dispose() {
    _diagnosticsFlushTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(393, 854),
      ensureScreenSize: true,
      minTextAdapt: true,
      builder: (BuildContext context, _) {
        return MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => UserProfileProvider()),
            ChangeNotifierProvider(create: (_) => PeriodLeaveProvider()),
            ChangeNotifierProvider(
              create: (context) => RunnerRtDataProvider(
                periodLeave: context.read<PeriodLeaveProvider>(),
                userProfile: context.read<UserProfileProvider>(),
              ),
            ),
            ChangeNotifierProvider(create: (_) => LoginSelfieProvider()),
            ChangeNotifierProvider(create: (_) => LanguageProvider()),
            ChangeNotifierProvider(create: (_) => PayoutProvider()),
            ChangeNotifierProvider(create: (_) => CurrentPeriodProvider()),
            ChangeNotifierProvider(create: (_) => LeaveApplicationData()),
            ChangeNotifierProvider(create: (_) => ReferralDataProvider()),
            ChangeNotifierProvider(create: (_) => ContestDataProvider()),
            ChangeNotifierProvider(create: (_) => PreferredLanguageProvider()),
            ChangeNotifierProvider(create: (_) => DocumentsProvider()),
            ChangeNotifierProvider(create: (_) => CurrentPictureProvider()),
            ChangeNotifierProvider(create: (_) => TrainingDayProvider()),
            ChangeNotifierProvider(create: (_) => DailyEarningsProvider()),
            ChangeNotifierProvider(create: (_) => DailyEarningsListProvider()),
            ChangeNotifierProvider(create: (_) => TipsProvider()),
            ChangeNotifierProvider(create: (_) => SOSProvider()),
            ChangeNotifierProvider(create: (_) => OnTheJobStateProvider()),
            ChangeNotifierProvider(create: (_) => PermissionPopupProvider()),
            ChangeNotifierProvider(
                create: (_) => NotificationPermissionPopupProvider()),
            ChangeNotifierProvider(create: (_) => RatingBlockProvider()),
            ChangeNotifierProvider(create: (_) => PipProvider()),
            ChangeNotifierProvider(create: (_) => OverlayProvider()),
            ChangeNotifierProvider(create: (_) => InsuranceProfileProvider()),
            ChangeNotifierProvider(create: (_) => PotentialEarningsProvider()),
            ChangeNotifierProvider(
              create: (_) => BottomSheetViewProvider(),
            ),
            ChangeNotifierProvider(create: (_) => WalletProvider()),
            ChangeNotifierProvider(create: (_) => PayoutHistoryProvider()),
            ChangeNotifierProvider(create: (_) => InfoBannerProvider()),
            ChangeNotifierProvider(create: (_) => OnboardingStepsProvider()),
            ChangeNotifierProvider(
                create: (_) => CredentialsManagementProvider()),
            ChangeNotifierProvider(
                create: (_) => AadhaarReverificationProvider()),
            ChangeNotifierProvider(create: (_) => EarlyPayoutsProvider()),
            ChangeNotifierProvider(create: (_) => AutoOtProvider()),
            ChangeNotifierProvider(create: (_) => LoanProvider()),
            ChangeNotifierProvider(create: (_) => BannerConfigProvider()),
            ChangeNotifierProvider(create: (_) => PartnerHomeInitProvider()),
            ChangeNotifierProvider(create: (_) => SelectLanguageInitProvider()),
            ChangeNotifierProvider(
                create: (_) => ProvisionalAttendanceBeforeLogoutProvider()),
          ],
          child: MaterialApp(
              navigatorObservers: [
                NavObserver(),
                appRouteObserver,
                // Scout RUM screen/route tracking — attached unconditionally.
                // Scout's own observer callbacks guard every emit on
                // `ScoutFlutter.isInitialized` and wrap the breadcrumb
                // platform-channel write in try/catch, so pre-init screen
                // changes silently no-op. Gating this on Base14's isActive
                // would race: `initializeAllServices()` is fire-and-forget
                // (`unawaited(...)` at main.dart:478) and this list is
                // captured once at MaterialApp build, so a slow init would
                // leave the observer permanently unattached.
                ScoutFlutter.navigatorObserver,
                // Debug-only: lets ChuckerFlutter.showChuckerScreen() resolve
                // the root navigator. navigatorKey is already taken by the app.
                // ignore: deprecated_member_use
                if (kDebugMode) ChuckerFlutter.navigatorObserver,
                // Debug-only: hides the native NET button while the chucker_flutter inspector is open.
                if (kDebugMode) DebugNetworkInspector.instance.routeObserver,
              ],
              title: 'Snabbit Expert',
              debugShowCheckedModeBanner: false,
              navigatorKey: GlobalState().navigatorKey,
              // Debug-only: overlays the draggable Chucker inspector launcher
              // above every screen. Returns child unchanged in release.
              builder: (context, child) =>
                  DebugNetworkInspector.instance.wrap(child),
              // theme: ThemeData(
              //   colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
              //   useMaterial3: true,
              // ),
              theme: AppTheme.lightTheme,
              routes: appRoutes,
              home: loading || initialScreen == null
                  ? const Loader()
                  : initialScreen
              // home: const UploadDocuments(),
              ),
        );
      },
    );
  }
}

/// The app's named-route table — the single source of truth for `Navigator`
/// route resolution. Used both by [MaterialApp.routes] above and by the KMP
/// navigation bridge's [HostBackedRoute], so a host-backed Flutter route (the
/// reordering round trip) builds the exact same widget `pushNamed` would.
final Map<String, WidgetBuilder> appRoutes = <String, WidgetBuilder>{
  ...GoLiveFlowController.getRoutes(),
  Loader.routeName: (context) => const Loader(),
  SelectLanguageV2.routeName: (context) => const SelectLanguageV2(),
  SendOtp.routeName: (context) => const SendOtp(),
  PersonalDetails.routeName: (context) => const PersonalDetails(),
  FamilyDetails.routeName: (context) => const FamilyDetails(),
  FamilyDetailsIfUnmarried.routeName: (context) =>
      const FamilyDetailsIfUnmarried(),
  FamilyDetailsIfDivorced.routeName: (context) =>
      const FamilyDetailsIfDivorced(),
  FamilyDetailsIfWidowed.routeName: (context) => const FamilyDetailsIfWidowed(),
  FamilyDetailsIfMarried.routeName: (context) => const FamilyDetailsIfMarried(),
  PriorExperience.routeName: (context) => const PriorExperience(),
  UploadDocuments.routeName: (context) => const UploadDocuments(),
  BankDetails.routeName: (context) => const BankDetails(),
  InsuranceDetails.routeName: (context) => const InsuranceDetails(),
  AvailabilityDetails.routeName: (context) => const AvailabilityDetails(),
  AvailabilityDetails2.routeName: (context) => const AvailabilityDetails2(),
  VerificationDisplay.routeName: (context) => const VerificationDisplay(),
  //Partner home pages
  PartnerHome.routeName: (context) => const PartnerHome(),
  //Shift Login (w/ selfie and latlng)
  SelfieForLogin.routeName: (context) => const SelfieForLogin(),
  SelfiePreview.routeName: (context) => const SelfiePreview(),
  IntegrityTestWidget.routeName: (context) => const IntegrityTestWidget(),
  Skills.routeName: (context) => const Skills(),
  CustomerService.routeName: (context) => const CustomerService(),
  PayoutHome.routeName: (context) => const PayoutHome(),
  Attendance.routeName: (context) => const Attendance(),
  NetEarnings.routeName: (context) => const NetEarnings(),
  Performance.routeName: (context) => const Performance(),
  OvertimeDetails.routeName: (context) => const OvertimeDetails(),
  DeductionDetails.routeName: (context) => const DeductionDetails(),
  IncentiveDetails.routeName: (context) => const IncentiveDetails(),
  LanguageHome.routeName: (context) => const LanguageHome(),
  LongLeaveApplication.routeName: (context) => const LongLeaveApplication(),
  RegistrationCode.routeName: (context) => const RegistrationCode(),
  SelectService.routeName: (context) => const SelectService(),
  RegistrationCodeV2.routeName: (context) => const RegistrationCodeV2(),
  ReferralsHome.routeName: (context) => const ReferralsHome(),
  GettingStarted.routeName: (context) => const GettingStarted(),
  FrontendPreviewHome.routeName: (context) => const FrontendPreviewHome(),
  if (kDebugMode) DebugMenu.routeName: (context) => const DebugMenu(),
  LearnMore.routeName: (context) => const LearnMore(),
  WorkExperience.routeName: (context) => const WorkExperience(),
  TrainingSlots.routeName: (context) => const TrainingSlots(),
  TrainingProgress.routeName: (context) => const TrainingProgress(),
  TncAcceptPage.routeName: (context) => const TncAcceptPage(),
  UniformConfirmationPage.routeName: (context) =>
      const UniformConfirmationPage(),
  ShiftTimingsPage.routeName: (context) => const ShiftTimingsPage(),
  BonusHome.routeName: (context) => const BonusHome(),
  DailyEarningsList.routeName: (context) => const DailyEarningsList(),
  TipsInfoScreen.routeName: (context) => const TipsInfoScreen(),
  DailyEarningState.routeName: (context) => const DailyEarningState(),
  IdentityCard.routeName: (context) => const IdentityCard(),
  InsuranceSupport.routeName: (context) => const InsuranceSupport(),
  UploadDocumentsPan.routeName: (context) => const UploadDocumentsPan(),
  RegistrationReview.routeName: (context) => const RegistrationReview(),
  ChildrenDetails.routeName: (context) => const ChildrenDetails(),
  TrainingDetails.routeName: (context) => const TrainingDetails(),
  PhoneIntegrityCheck.routeName: (context) => const PhoneIntegrityCheck(),
  DeviceTesting.routeName: (context) => const DeviceTesting(),
  PotentialEarnings.routeName: (context) => const PotentialEarnings(),
  WeekendEarnings.routeName: (context) => const WeekendEarnings(),
  ConfirmShiftTimings.routeName: (context) => const ConfirmShiftTimings(),
  FestiveBonusScreen.routeName: (context) => const FestiveBonusScreen(),
  IssueHistory.routeName: (context) => const IssueHistory(),
  NewIssueReporter.routeName: (context) => const NewIssueReporter(),
  WalletHome.routeName: (context) => const WalletHome(),
  ReferralContacts.routeName: (context) => const ReferralContacts(),
  DiwaliContestPage.routeName: (context) {
    return const DiwaliContestPage();
  },
  OnboardingScreen.routeName: (context) => const OnboardingScreen(),
  UploadAadhaarPhotos.routeName: (context) => const UploadAadhaarPhotos(),
  AadhaarDetails.routeName: (context) => const AadhaarDetails(),
  AadhaarNumberUpdater.routeName: (context) => const AadhaarNumberUpdater(),
  VoterIDUpdater.routeName: (context) => const VoterIDUpdater(),
  PanNumberUpdater.routeName: (context) => const PanNumberUpdater(),
  OnboardingSingleQuestionScreen.routeName: (context) =>
      const OnboardingSingleQuestionScreen(),
  OnboardingMultipleQuestionsScreen.routeName: (context) =>
      const OnboardingMultipleQuestionsScreen(),
  LocationChangeV2.routeName: (context) => const LocationChangeV2(),
  PersonalDetailsReviewV3.routeName: (context) =>
      const PersonalDetailsReviewV3(),
  OnboardingStatusView.routeName: (context) => const OnboardingStatusView(),
  OnboardingFailedView.routeName: (context) => const OnboardingFailedView(),
  AadhaarValidator.routeName: (context) => const AadhaarValidator(),
  AadhaarReverificationPage.routeName: (context) =>
      const AadhaarReverificationPage(),
  AddBankOrUpiDetailsScreen.routeName: (context) =>
      const AddBankOrUpiDetailsScreen(),
  UpiDetailsScreen.routeName: (context) => const UpiDetailsScreen(),
  AccountConfirmationTnC.routeName: (context) => const AccountConfirmationTnC(),
  AccountOtpVerification.routeName: (context) => const AccountOtpVerification(),
  BankAccountDetailsScreen.routeName: (context) =>
      const BankAccountDetailsScreen(),
  EnterUpiDetails.routeName: (context) => const EnterUpiDetails(),
  EnterBankDetails.routeName: (context) => const EnterBankDetails(),
  EarlyPayoutsScreen.routeName: (context) => const EarlyPayoutsScreen(),
  TransactionHistory.routeName: (context) => const TransactionHistory(),
  ChatScreen.routeName: (context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    String source = 'button';
    if (args is Map<String, dynamic>) {
      source = args['source'] as String? ?? 'button';
    } else if (args is String) {
      source = args;
    }
    return ChatScreen(source: source);
  },
  AppWebViewPage.routeName: (context) => const AppWebViewPage(),
};

class Loader extends StatelessWidget {
  static const String routeName = "loader";

  const Loader({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.n0,
      appBar: AppBar(),
      body: const Center(
        child: Center(
          child: CupertinoActivityIndicator(),
        ),
      ),
    );
  }
}
