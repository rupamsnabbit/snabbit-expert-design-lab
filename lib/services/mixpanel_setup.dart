import 'package:snabbit_runner/services/analytics/kmp_analytics_channel.dart';

/// Mixpanel facade. Thin shim over [KmpAnalyticsChannel] kept for call-site
/// compatibility (~60 `logEvent` sites). Routing lives in the KMP catalog,
/// not the facade — calling this vs [ClevertapSetup.logEvent] reaches the
/// same KMP entry point and fans out the same way. DO NOT add a parallel
/// `ClevertapSetup.logEvent` next to a call here; you'd double-fire.
///
/// Super-property merging moved to [KmpAnalyticsChannel.track] — every
/// event (whichever facade fired it) now picks up registered super-props
/// before crossing.
class MixpanelSetup {
  MixpanelSetup._();
  static final MixpanelSetup instance = MixpanelSetup._();

  /// Kept for call-site compatibility (`main.dart`). Mixpanel is started
  /// by the KMP bootstrap; nothing to initialise here.
  Future<void> initialize() async {}

  /// `targets` is optional and additive: app call sites leave it null so
  /// destinations come from the KMP catalog (unchanged). The webview sink
  /// passes explicit targets to route without needing webview names in the
  /// catalog.
  static Future<void> logEvent(
    String eventName,
    Map<String, dynamic> eventData, {
    List<String>? targets,
  }) =>
      KmpAnalyticsChannel.instance
          .track(name: eventName, props: eventData, targets: targets);

  static Future<void> identify(String? userId) {
    if (userId == null) return Future.value();
    return KmpAnalyticsChannel.instance.identify(userId: userId);
  }

  /// Fans the whole profile in a single MethodChannel crossing. Null
  /// values are dropped by KMP-side sanitisation, so callers can pass an
  /// unfiltered map. No-ops if the map is empty after null-stripping.
  static Future<void> setUserProfile(Map<String, dynamic> props) {
    if (props.isEmpty) return Future.value();
    return KmpAnalyticsChannel.instance.setUserProperties(props);
  }

  /// Forwards to [KmpAnalyticsChannel.registerSuperProperties]. Later calls
  /// win on conflict. Super-props now reach every provider the route table
  /// fans an event to — not just Mixpanel.
  static Future<void> registerSuperProperties(Map<String, dynamic> props) {
    KmpAnalyticsChannel.instance.registerSuperProperties(props);
    return Future.value();
  }

  /// Test-only: clear the super-property store between tests.
  static void resetForTest() => KmpAnalyticsChannel.resetSuperPropsForTest();
}
