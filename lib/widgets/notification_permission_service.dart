import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../main.dart';
import '../services/globals.dart';
import '../services/monitoring/monitoring_service_helper.dart';
import '../services/notification_service.dart';

class NotificationPermissionPopupProvider with ChangeNotifier {
  bool _notificationPermissionAlert = false;
  bool notificationPermissionSystem = false;
  // NotificationQueueService? notificationQueueService;

  bool get notificationPermissionAlert => _notificationPermissionAlert;

  set notificationPermissionAlert(bool value) {
    _notificationPermissionAlert = value;
    // notifyListeners();
  }
}

Future<bool> isNotificationPermissionDenied() async {
  final settings = await FirebaseMessaging.instance.getNotificationSettings();
  MonitoringServiceHelper.logInfo(
    'FirebaseMessaging Notification Permission Request',
    {
      'component': 'NotificationPermissionPopupProvider',
      'status': settings.authorizationStatus.name,
      'timestamp': DateTime.now().toIso8601String(),
    },
  );
  return settings.authorizationStatus == AuthorizationStatus.denied ||
      settings.authorizationStatus == AuthorizationStatus.notDetermined;
}

/// Tracks whether FCM foreground listener has been registered to prevent duplicates
bool _isFCMListenerRegistered = false;

void showNotificationPermissionConfirmation() async {
  try {
    final provider = Provider.of<NotificationPermissionPopupProvider>(
        GlobalState().navigatorKey.currentContext!,
        listen: false);
    if (provider.notificationPermissionSystem == true) throw "Already opened";
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    provider.notificationPermissionSystem = true;
    final status = await Permission.notification.status;
    NotificationSettings? settings;
    if (status != PermissionStatus.permanentlyDenied) {
      settings = await messaging.requestPermission(
        alert: true,
        announcement: true,
        badge: true,
        provisional: false, // Required for Android 13+
      );
    }
    provider.notificationPermissionSystem = false;
    if ((Platform.isAndroid &&
            (status == PermissionStatus.granted ||
                status == PermissionStatus.provisional)) ||
        (Platform.isIOS &&
            settings?.authorizationStatus == AuthorizationStatus.authorized)) {
      if (provider.notificationPermissionAlert == true) {
        Navigator.of(GlobalState().navigatorKey.currentContext!).pop();
      }
      debugPrint('User granted permission for notifications');
      // Handle background messages (optional)
      MonitoringServiceHelper.logInfo(
        'FirebaseMessaging Notification Permission Request',
        {
          'component': 'NotificationPermissionPopupProvider',
          'status': status.name,
        },
      );
      await initNotificationPlugin();
      await NotificationService.instance.createNotificationChannel();
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        announcement: true,
        sound: true,
        badge: true,
        criticalAlert: true,
        provisional: true, // Required for Android 13+
      );
      // Initialize the queue service (or use dependency injection)
      // provider.notificationQueueService = NotificationQueueService();

      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      // Handle foreground - only register once to prevent duplicate listeners
      if (!_isFCMListenerRegistered) {
        _isFCMListenerRegistered = true;
        FirebaseMessaging.onMessage.listen(firebaseMessagingForegroundHandler);
      }
    } else {
      if ((status == PermissionStatus.permanentlyDenied ||
              status == PermissionStatus.denied) &&
          provider.notificationPermissionAlert == false) {
        MonitoringServiceHelper.logWarning(
          'FirebaseMessaging Notification Permission Request',
          {
            'component': 'NotificationPermissionPopupProvider',
            'status': status.name,
          },
        );
        provider.notificationPermissionAlert = true;
        showDialog(
          barrierDismissible: false,
          context: GlobalState().navigatorKey.currentContext!,
          builder: (BuildContext context) {
            return const CompulsoryNotificationPermissionDialog();
          },
        ).then((_) {
          provider.notificationPermissionAlert = false;
        });
      }
    }
  } catch (e) {
    // DO NOTHING
  }
}

class CompulsoryNotificationPermissionDialog extends StatelessWidget {
  const CompulsoryNotificationPermissionDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Allow notification permission"),
        content: const Text(
            "Snabbit Expert requires notification permission for important updates. Please enable notifications in your device settings."),
        actions: <Widget>[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                // Navigator.of(context).pop();
                // await Future.delayed(Duration(milliseconds: 500));
                await openAppSettings();
              },
              child: const Text("Open Settings"),
            ),
          ),
        ],
      ),
    );
  }
}

/// Logs the initial notification permission status at app start.
/// Call once from main() before showing any notification permission UI.
Future<void> logInitialNotificationPermissionStatus() async {
  try {
    final notificationStatus = await Permission.notification.status;
    String fcmAuthorizationStatus = 'unavailable';
    try {
      final settings =
          await FirebaseMessaging.instance.getNotificationSettings();
      fcmAuthorizationStatus = settings.authorizationStatus.name;
    } catch (_) {}
    //need to shorten, simplify and snake_case the event name
    await MonitoringServiceHelper.logInfo(
      'app_start_notification_permission_status',
      {
        'component': 'AppStart',
        'notification_status': notificationStatus.name,
        'fcm_authorization_status': fcmAuthorizationStatus,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  } catch (e) {
    await MonitoringServiceHelper.logCriticalError(
      'app_start_notification_permission_status_failed',
      {
        'component': 'AppStart',
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }
}
