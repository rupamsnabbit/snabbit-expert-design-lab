import 'analytics/kmp_analytics_channel.dart';

/// CleverTap facade — events + identity only. Everything routes through the
/// KMP analytics module; the native CleverTap SDK is the sender. Push is
/// rendered by the app's own notification stack (see NotificationService /
/// _handleCleverTapPush), so there are no push handlers here anymore.
class ClevertapSetup {
  ClevertapSetup._();
  static final ClevertapSetup instance = ClevertapSetup._();

  static Future<void> logEvent(
          String eventName, Map<String, dynamic> eventData) =>
      KmpAnalyticsChannel.instance.track(name: eventName, props: eventData);

  static Future<void> setCustomer(Map<String, dynamic> eventData) =>
      KmpAnalyticsChannel.instance.setCustomer(eventData);
}
