import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';

import '../pages/chat/chat_screen.dart';
import '../providers/auto_ot_provider.dart';
import '../providers/runner_rt_data.dart';
import '../providers/user_profile.dart';
import '../services/clevertap.dart';
import '../services/deeplink/deeplink_result.dart';
import '../services/deeplink/deeplink_router.dart';
import 'analytics/kmp_analytics_channel.dart';
import '../utils/common_methods.dart';
import '../utils/tracking_events.dart';
import 'globals.dart';
import '../modules/snabbit_shield/shield_sos_push_store.dart';
import 'monitoring/monitoring_service_helper.dart';

/// Service for handling all notification-related functionality
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const AndroidInitializationSettings _initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  static const InitializationSettings _initializationSettings =
      InitializationSettings(
    android: _initializationSettingsAndroid,
  );

  final AndroidNotificationChannel channel = const AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'This channel is used for important notifications.',
    importance: Importance.high,
    audioAttributesUsage: AudioAttributesUsage.alarm,
    enableVibration: false,
  );

  /// Initialize the notification plugin with tap handlers
  Future<void> initialize() async {
    await flutterLocalNotificationsPlugin.initialize(
      _initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // Handle notification tap from local notifications
        if (response.payload != null) {
          try {
            final data = jsonDecode(response.payload!);
            await handleNotificationTap(Map<String, dynamic>.from(data));
          } catch (e) {
            MonitoringServiceHelper.logError(
              'LOCAL_NOTIFICATION_PAYLOAD_PARSE_FAILED',
              {'error': e.toString()},
            );
          }
        }
      },
    );
  }

  /// Set up FCM notification tap handlers for background and killed state
  void setupFCMTapHandlers() {
    // Handle notification when app is opened from killed state
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        // Use the unified handleNotificationTap function
        WidgetsBinding.instance.addPostFrameCallback((_) {
          handleNotificationTap(message.data);
        });
      }
    });

    // Handle notification when app is opened from background
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      // Use the unified handleNotificationTap function
      handleNotificationTap(message.data);
    });

    // Killed-state tap of a self-rendered (local) notification — e.g. a
    // CleverTap push drawn by us in the background isolate.
    flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails().then((d) {
      final payload = d?.notificationResponse?.payload;
      if ((d?.didNotificationLaunchApp ?? false) && payload != null) {
        try {
          handleNotificationTap(Map<String, dynamic>.from(jsonDecode(payload)));
        } catch (e, stackTrace) {
          MonitoringServiceHelper.logError(
            'KILLED_STATE_NOTIFICATION_PAYLOAD_PARSE_FAILED',
            {
              'error': e.toString(),
              'stack_trace': stackTrace.toString(),
            },
          );
        }
      }
    });
  }

  /// Handle notification tap and route to appropriate screen.
  ///
  /// Deeplink-first: a `deeplink` (our FCM key) or `wzrk_dl` (CleverTap's native
  /// deep-link field) is routed through [DeepLinkRouter]. If the router consumes
  /// it (`handled`/`queued`) we stop; if the kill switch is off (`notHandled`)
  /// we fall through to the legacy notification-`type` switch, which is also the
  /// path for all existing non-deeplink payloads.
  Future<void> handleNotificationTap(Map<String, dynamic> data) async {
    final deeplinkValue = data['deeplink'] ?? data['wzrk_dl'];
    if (deeplinkValue is String && deeplinkValue.isNotEmpty) {
      final uri = Uri.tryParse(deeplinkValue);
      if (uri != null) {
        // CleverTap payloads carry `wzrk_`-prefixed keys; everything else is
        // a backend FCM data message.
        final isCleverTap = data.keys.any((key) => key.startsWith('wzrk_'));
        final result = await DeepLinkRouter.instance.dispatch(
          uri,
          source: isCleverTap
              ? DeeplinkSource.clevertap
              : DeeplinkSource.notification,
        );
        if (result != DeepLinkResult.notHandled) return;
      } else {
        MonitoringServiceHelper.logWarning(
          'NOTIFICATION_DEEPLINK_PARSE_FAILED',
          {'value': deeplinkValue},
        );
      }
    }

    final notificationType = data['type'];
    final context = GlobalState().navigatorKey.currentContext;

    if (context == null) {
      // Context not available yet, schedule for later
      WidgetsBinding.instance.addPostFrameCallback((_) {
        handleNotificationTap(data);
      });
      return;
    }

    // CleverTap push (we self-render) → tell CleverTap it was clicked.
    // Past the context guard so the re-entry loop above doesn't multi-fire it.
    if (data.keys.any((k) => k.startsWith('wzrk_'))) {
      KmpAnalyticsChannel.instance
          .ctPushClicked(Map<String, Object?>.from(data));
    }

    await _actionOnDeeplinkAndNotificationTap(notificationType, data, context);
  }

  /// Route notification tap to appropriate screen based on type
  Future<void> _actionOnDeeplinkAndNotificationTap(
    String? notificationType,
    Map<String, dynamic> data,
    BuildContext context,
  ) async {
    // New-job pushes are marked by `name` (not `type`). A tapped new-job
    // notification just needs the app foregrounded (the tap does that) + a
    // fresh state fetch, so the state-driven job surface — the KMP overlay or
    // the new-job screen — appears. Mirrors the AUTO_OT_REQUEST refresh below.
    if (data['name'] == 'NEW_JOB_ALLOCATION') {
      try {
        Provider.of<RunnerRtDataProvider>(context, listen: false).fetchDataNow();
      } catch (e) {
        MonitoringServiceHelper.logWarning(
          'NOTIFICATION_NEW_JOB_TAP_FAILED',
          {'error': e.toString()},
        );
      }
      return;
    }
    switch (notificationType) {
      case 'customer_chat':
        try {
          final userProfileProvider =
              Provider.of<UserProfileProvider>(context, listen: false);
          ClevertapSetup.logEvent(TrackingEvents.chatP2pclicked, {
            'job_id': data['job_id'],
            'customer_id': data['customer_id'],
            'expert_id': userProfileProvider.user?.id.toString(),
            'source': 'push',
          });
        } catch (e) {
          MonitoringServiceHelper.logWarning(
            'NOTIFICATION_CHAT_ANALYTICS_FAILED',
            {'error': e.toString()},
          );
        }
        // Navigate to chat screen
        Navigator.of(context).pushNamed(
          ChatScreen.routeName,
          arguments: {'source': 'notification'},
        );
        break;
      case 'AUTO_OT_REQUEST':
        // Trigger fetchDataNow for Auto-OT
        try {
          Provider.of<RunnerRtDataProvider>(context, listen: false)
              .fetchDataNow();
        } catch (e) {
          MonitoringServiceHelper.logWarning(
            'NOTIFICATION_AUTO_OT_REQUEST_FAILED',
            {'error': e.toString()},
          );
        }
        break;
      case 'AUTO_OT_CANCELLED':
        // Handle cancellation
        try {
          Provider.of<AutoOtProvider>(context, listen: false)
              .handleAutoOtCancellation();
        } catch (e) {
          MonitoringServiceHelper.logWarning(
            'NOTIFICATION_AUTO_OT_CANCELLED_FAILED',
            {'error': e.toString()},
          );
        }
        break;
      case 'safety_shield_sos':
        try {
          final action = data['action'] as String?;
          final sosId = anyValueToInt(data['sos_id']);
          if (action != null && sosId != null) {
            final adapter = GlobalState().shieldAdapter;
            if (adapter != null) {
              await adapter.handleSOSNotification(action: action, sosId: sosId);
            } else {
              // Adapter not ready — persist so it's reconciled on next
              // foreground rather than being dropped.
              await ShieldSosPushStore.persist(action: action, sosId: sosId);
            }
          }
        } catch (e) {
          MonitoringServiceHelper.logError(
            'NOTIFICATION_SAFETY_SHIELD_SOS_FAILED',
            {'error': e.toString()},
          );
        }
        break;
      default:
        // Default behavior - no specific navigation
        break;
    }
  }

  /// Show a local notification with the given details
  Future<void> showNotification({
    required int id,
    required String? title,
    required String? body,
    String? payload,
  }) async {
    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: Importance.max,
          priority: Priority.high,
          fullScreenIntent: true,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          enableVibration: false,
        ),
      ),
      payload: payload,
    );
  }

  /// Create the notification channel (Android only)
  Future<void> createNotificationChannel() async {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Cancel all notifications
  Future<void> cancelAll() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  /// Cancel a specific notification by ID
  Future<void> cancel(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }
}
