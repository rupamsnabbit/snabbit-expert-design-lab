import 'package:snabbit_runner/models/delayed_checkin/delayed_checkin_models.dart';
import 'package:snabbit_runner/services/tracking/tracking_common.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';

/// Analytics helper for delayed check-in penalty events — Mixpanel only.
class DelayedCheckinTracking {
  DelayedCheckinTracking._();

  static const _context = 'DELAYED_CHECKIN_TRACKING';

  static Map<String, dynamic> _getPenaltyAttributes(DelayedCheckinData data) {
    return {'received_red_cards': data.receivedRedCards};
  }

  /// Fires when the delayed check-in penalty dialog appears.
  static Future<void> trackPopupViewed({
    required DelayedCheckinData data,
  }) async {
    final props = {
      ...TrackingCommon.getExpertAttributes(),
      ..._getPenaltyAttributes(data),
    };
    await TrackingCommon.logMixpanelEvent(
      TrackingEvents.delayedCheckinPenaltyPopupViewed,
      props,
      crashlyticsContext: _context,
    );
  }
}
