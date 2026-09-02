import 'package:snabbit_runner/models/common/countdown_model.dart';
import 'package:snabbit_runner/utils/common_methods.dart';

/// Root data model for the delayed check-in penalty overlay.
/// Parsed from `widgetInfo.data['delayed_checkin_penalty']`.
class DelayedCheckinData {
  final CountdownData? countdown;
  final int? receivedRedCards;

  DelayedCheckinData({
    this.countdown,
    this.receivedRedCards,
  });

  factory DelayedCheckinData.fromJson(Map<String, dynamic>? json) {
    if (json == null) return DelayedCheckinData();
    return DelayedCheckinData(
      countdown: json['countdown'] is Map<String, dynamic>
          ? CountdownData.fromJson(json['countdown'])
          : null,
      receivedRedCards: anyValueToInt(json['received_red_cards']),
    );
  }
}
