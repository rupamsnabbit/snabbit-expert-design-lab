import 'package:snabbit_runner/services/mixpanel_setup.dart';

/// Narrow seam around the app's analytics so bifrost code depends on this,
/// not the facade directly. With one impl today the interface is thin —
/// kept as a placeholder for a second bifrost analytics consumer and as
/// the injection point for the handler-level test fake. If no second
/// consumer materialises, fold into [TrackEventHandler] and switch the
/// handler test to a MethodChannel mock.
abstract class AnalyticsSink {
  Future<void> track(String name, Map<String, Object?> properties);
}

/// Forwards web events to Mixpanel + CleverTap + AppsFlyer. Webview names
/// aren't in the central catalog, so the explicit `targets` carries the
/// providers directly. Super properties are merged at the
/// [KmpAnalyticsChannel] layer, so any facade (Mixpanel-named here for
/// historical reasons) picks them up identically.
///
/// AppsFlyer is included because the marketing onboarding funnel events
/// (gender_selected_*, city_detection_screen_cta_click, pre_registration_
/// complete) originate in the webview; without it they never reach AppsFlyer
/// and campaign optimisation loses its signal.
// ponytail: blanket AppsFlyer on all web events — sends every webview event to
// AppsFlyer, not only the funnel ones. Gate by event name (union with the KMP
// route table) if noise/cost on AppsFlyer becomes a problem.
class KmpWebAnalyticsSink implements AnalyticsSink {
  const KmpWebAnalyticsSink();

  @override
  Future<void> track(String name, Map<String, Object?> properties) {
    return MixpanelSetup.logEvent(
      name,
      Map<String, dynamic>.from(properties),
      targets: const ['Mixpanel', 'CleverTap', 'AppsFlyer'],
    );
  }
}
