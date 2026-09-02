import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/widgets/payout/shift_performance_breakdown_card.dart';

class ShiftEarningSummary {
  final String? shiftPerformanceTitle;
  final String? breakdown;
  final int? amount;
  final bool? isActive;
  final ShiftPerformance shiftPerformance;

  ShiftEarningSummary({
    required this.shiftPerformanceTitle,
    required this.breakdown,
    this.amount,
    this.isActive,
    required this.shiftPerformance,
  });

  factory ShiftEarningSummary.fromJson(Map<String, dynamic> json) {
    return ShiftEarningSummary(
      shiftPerformanceTitle: json['shift_performance_title'],
      breakdown: json['breakdown'],
      amount: anyValueToInt(json['amount']),
      isActive: json['is_active'],
      shiftPerformance: ShiftPerformance.fromString(json['shift_performance']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shift_performance_title': shiftPerformanceTitle,
      'breakdown': breakdown,
      'amount': amount,
      'is_active': isActive,
      'shift_performance': shiftPerformance.toString().split('.').last,
    };
  }
}
