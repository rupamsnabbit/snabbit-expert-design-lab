import 'package:snabbit_runner/utils/common_methods.dart';

/// Generic countdown timer model shared across features (AWOL, delayed check-in, etc.).
class CountdownData {
  static const int defaultTotalSeconds = 300;
  static const int defaultRemainingSeconds = 0;

  final int? remainingSeconds;
  final int? totalSeconds;

  /// Absolute timestamp when the deadline fires.
  /// Remaining time is computed as `triggerAt − now`; a past value means
  /// the countdown has expired (negative = "LATE BY" elapsed time).
  final DateTime? triggerAt;

  CountdownData({this.remainingSeconds, this.totalSeconds, this.triggerAt});

  int get totalSecondsOrDefault => totalSeconds ?? defaultTotalSeconds;
  int get remainingSecondsOrDefault => remainingSeconds ?? defaultRemainingSeconds;

  factory CountdownData.fromJson(Map<String, dynamic>? json) {
    if (json == null) return CountdownData();
    return CountdownData(
      remainingSeconds: anyValueToInt(json['remaining_seconds']),
      totalSeconds: anyValueToInt(json['total_seconds']),
      triggerAt: parseDateTime(json['trigger_at']),
    );
  }
}
