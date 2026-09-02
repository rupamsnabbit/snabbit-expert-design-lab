import 'package:snabbit_runner/models/tiering/tier_nudge.dart';
import 'package:snabbit_runner/services/mixpanel_setup.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';

/// Analytics for the tiering widgets (`lib/widgets/tiering`).
///
/// Every event fans to **both Mixpanel and CleverTap** via an explicit
/// `targets` list. The tiering event names aren't in the KMP analytics route
/// catalog, so — exactly like the bifrost webview sink — we name both providers
/// here rather than relying on the catalog (whose universal-sink default would
/// otherwise send these to Mixpanel only). See
/// `lib/services/webview/analytics_sink.dart`.
///
/// All firing is guarded: any failure while building the props map or crossing
/// the analytics channel is reported to [MonitoringServiceHelper] and never
/// thrown back at the widget. (The channel itself is already best-effort; this
/// is defence-in-depth around the call site's prop assembly.)
class TieringAnalytics {
  TieringAnalytics._();

  /// Home-nudge render variants (the `render_type` prop on nudge events).
  static const String renderTypeCoinsCard = 'coins_card';
  static const String renderTypeJob = 'job';
  static const String renderTypeThemed = 'themed';

  /// Both providers, mirroring the webview sink's explicit targeting.
  static const List<String> _bothProviders = ['Mixpanel', 'CleverTap'];

  // ── Home nudge (ApplicableTieringNudge + its render variants) ──────────────

  static void nudgeViewed(TierNudge nudge, Tier? tier, String renderType) =>
      _fire(TrackingEvents.tieringNudgeViewed,
          () => _nudgeProps(nudge, tier, renderType));

  static void nudgeClicked(TierNudge nudge, Tier? tier, String renderType) =>
      _fire(TrackingEvents.tieringNudgeClicked,
          () => _nudgeProps(nudge, tier, renderType));

  // ── Snabbit Udaan intro banner ─────────────────────────────────────────────

  static void bannerViewed({required bool showHeaderImage}) =>
      _fire(TrackingEvents.tieringUdaanBannerViewed,
          () => {'show_header_image': showHeaderImage});

  static void bannerClicked({required bool showHeaderImage}) =>
      _fire(TrackingEvents.tieringUdaanBannerClicked,
          () => {'show_header_image': showHeaderImage});

  // ── Drawer "View tier" row ─────────────────────────────────────────────────

  static void drawerViewed(Tier? tier) => _fire(
      TrackingEvents.tieringViewTierDrawerViewed, () => {'tier': _tier(tier)});

  static void drawerClicked(Tier? tier) => _fire(
      TrackingEvents.tieringViewTierDrawerClicked, () => {'tier': _tier(tier)});

  static Map<String, dynamic> _nudgeProps(
    TierNudge nudge,
    Tier? tier,
    String renderType,
  ) =>
      {
        'nudge_name': nudge.nudgeName ?? '',
        'theme': nudge.theme.name,
        'tier': _tier(tier),
        'render_type': renderType,
        'navigation_route': nudge.navigationRoute ?? '',
      };

  static String _tier(Tier? tier) => tier?.name ?? '';

  /// Builds the props and fires the event to both providers, converting any
  /// throw into a [MonitoringServiceHelper] report instead of crashing the UI.
  static void _fire(String event, Map<String, dynamic> Function() buildProps) {
    try {
      MixpanelSetup.logEvent(event, buildProps(), targets: _bothProviders);
    } catch (e, stackTrace) {
      MonitoringServiceHelper.reportError(
        'tiering_analytics_error',
        {'event': event, 'error': e.toString()},
        stackTrace.toString(),
      )
          // Deliberate: reportError is the last-resort sink — if it itself
          // rejects, logging that failure would recurse, so we swallow here only
          // to avoid an unhandled async error (there is nothing left to report to).
          .catchError((_) {});
    }
  }
}
