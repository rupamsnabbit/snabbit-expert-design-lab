import 'package:snabbit_runner/models/awol/awol_models.dart';
import 'package:snabbit_runner/services/tracking/tracking_common.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';

/// Analytics helper for AWOL events — Mixpanel only.
/// Follows the GoLiveV2Tracking pattern.
class AwolTracking {
  AwolTracking._();

  static const _context = 'AWOL_TRACKING';

  // ──────────────────────────────────────────────
  // Common attributes
  // ──────────────────────────────────────────────

  static Map<String, dynamic> _getAwolAttributes(AwolData? awolData) {
    if (awolData == null) return {};
    final durationMins = awolData.detectedAt != null
        ? DateTime.now().difference(awolData.detectedAt!).inMinutes
        : null;
    return {
      'awol_type': _awolType(awolData),
      'hood_name': awolData.hotspot?.name,
      'detected_at': awolData.detectedAt?.toIso8601String(),
      'duration_mins': durationMins,
    };
  }

  static String _awolType(AwolData awolData) {
    if (awolData.isJob) return 'job_awol';
    if (awolData.isBreach) {
      final remaining = awolData.countdown?.remainingSeconds ?? 0;
      return remaining > 0
          ? 'outside_hood_within_timer'
          : 'outside_hood_beyond_timer';
    }
    return 'outside_hood_beyond_timer';
  }

  /// Common props combining expert + awol attributes.
  static Map<String, dynamic> _getCommonProps(AwolData? awolData) {
    return {
      ...TrackingCommon.getExpertAttributes(),
      if (awolData != null) ..._getAwolAttributes(awolData),
    };
  }

  static Future<void> _logEvent(String event, Map<String, dynamic> props) =>
      TrackingCommon.logMixpanelEvent(event, props, crashlyticsContext: _context);

  // ──────────────────────────────────────────────
  // Events
  // ──────────────────────────────────────────────

  /// Fires when PartnerHome is shown or resumed.
  static Future<void> trackHomePageViewed({
    String? widgetName,
    AwolData? awolData,
  }) async {
    final props = {
      ..._getCommonProps(awolData),
      'widget_name': widgetName,
      'state': awolData != null ? 'awol' : 'normal',
    };
    await _logEvent(TrackingEvents.expertHomePageViewed, props);
  }

  /// Fires when AWOL dialog (FG) or native overlay (BG) appears.
  static Future<void> trackPopupViewed({
    required String overlayType,
    required AwolData awolData,
    int? timerCountShown,
  }) async {
    final isResolved = !awolData.isBreach;
    final ctas = awolData.isBreach
        ? ['show_directions', 'i_understood']
        : ['i_understood'];
    final props = {
      ..._getCommonProps(awolData),
      'overlay_type': overlayType,
      'ctas_displayed': ctas.join(','),
      'timer_count_shown': timerCountShown,
      'is_resolved': isResolved,
      if (isResolved) 'resolved_at': DateTime.now().toIso8601String(),
    };
    await _logEvent(TrackingEvents.awolPopupViewed, props);
  }

  /// Fires when any AWOL CTA is tapped.
  static Future<void> trackCtaClicked({
    required String ctaType,
    required String source,
    required String timerState,
    required AwolData awolData,
    int? timerCountAtAction,
  }) async {
    final props = {
      ..._getCommonProps(awolData),
      'cta_type': ctaType,
      'source': source,
      'timer_state': timerState,
      if (timerCountAtAction != null) 'timer_count_at_action': timerCountAtAction,
    };
    await _logEvent(TrackingEvents.awolCtaClicked, props);
  }


  /// Fires when AWOL state transitions.
  static Future<void> trackStateTransition({
    required String fromState,
    required String toState,
    AwolData? awolData,
  }) async {
    final props = {
      ..._getCommonProps(awolData),
      'from_state': fromState,
      'to_state': toState,
    };
    await _logEvent(TrackingEvents.awolStateTransition, props);
  }
}
