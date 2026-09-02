import 'dart:math';

import 'package:snabbit_runner/utils/common_methods.dart';

/// Response from `GET /api/v1/runners/me/period_leave/availability`.
class PeriodLeaveAvailability {
  const PeriodLeaveAvailability({
    required this.maxPeriodLeaves,
    required this.periodLeavesTaken,
    this.availableFromBackend,
  });

  final int maxPeriodLeaves;
  final int periodLeavesTaken;

  /// When null, UI should treat availability as `periodLeaveRemaining > 0`.
  final bool? availableFromBackend;

  int get periodLeaveTotal => maxPeriodLeaves;

  int get periodLeaveRemaining {
    final r = maxPeriodLeaves - periodLeavesTaken;
    return max(0, r);
  }

  bool get periodLeaveAvailable =>
      availableFromBackend ?? (periodLeaveRemaining > 0);

  factory PeriodLeaveAvailability.fromJson(Map<String, dynamic> json) {
    final maxLeaves = anyValueToInt(
          json['max_period_leaves'] ?? json['maxPeriodLeaves'],
        ) ??
        0;
    final taken = anyValueToInt(
          json['period_leaves_taken'] ?? json['periodLeavesTaken'],
        ) ??
        0;
    final av = json['available'];
    bool? availableFromBackend;
    if (av is bool) {
      availableFromBackend = av;
    } else if (av is String) {
      if (av == 'true') availableFromBackend = true;
      if (av == 'false') availableFromBackend = false;
    }
    return PeriodLeaveAvailability(
      maxPeriodLeaves: maxLeaves,
      periodLeavesTaken: taken,
      availableFromBackend: availableFromBackend,
    );
  }
}
