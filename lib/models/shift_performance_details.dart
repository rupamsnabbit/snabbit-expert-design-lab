import 'package:snabbit_runner/models/shift_earning_summary.dart';
import 'package:snabbit_runner/models/shift_insight.dart';
import 'package:snabbit_runner/models/shift_config.dart';
import 'package:snabbit_runner/widgets/payout/shift_performance_breakdown_card.dart';

class ShiftPerformanceDetails {
  final ShiftPerformance shiftPerformance;
  final ShiftConfig shiftConfig;
  final String title;
  final String subTitle;
  final List<String>? jobDenialDetails;
  final List<ShiftEarningSummary> shiftEarningSummaryList;
  final List<ShiftInsight> shiftInsightList;

  ShiftPerformanceDetails({
    required this.shiftPerformance,
    required this.shiftConfig,
    required this.title,
    required this.subTitle,
    required this.jobDenialDetails,
    required this.shiftEarningSummaryList,
    required this.shiftInsightList,
  });

  factory ShiftPerformanceDetails.fromJson(Map<String, dynamic> json) {
    return ShiftPerformanceDetails(
      shiftPerformance: ShiftPerformance.fromString(json['shift_performance']),
      shiftConfig: ShiftConfig.fromJson(json['shift_config'] ?? {}),
      title: json['title'] ?? '',
      subTitle: json['sub_title'] ?? '',
      jobDenialDetails: json['job_denial_details'] != null
          ? List<String>.from(json['job_denial_details'])
          : null,
      shiftEarningSummaryList: json['shift_earning_summary_list'] != null
          ? List<ShiftEarningSummary>.from(
              json['shift_earning_summary_list'].map(
                (item) => ShiftEarningSummary.fromJson(item),
              ),
            )
          : [],
      shiftInsightList: json['shift_insight_list'] != null
          ? List<ShiftInsight>.from(
              json['shift_insight_list'].map(
                (item) => ShiftInsight.fromJson(item),
              ),
            )
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shift_performance': shiftPerformance.toString().split('.').last,
      'shift_config': shiftConfig.toJson(),
      'title': title,
      'sub_title': subTitle,
      'job_denial_details': jobDenialDetails,
      'shift_earning_summary_list':
          shiftEarningSummaryList.map((item) => item.toJson()).toList(),
      'shift_insight_list':
          shiftInsightList.map((item) => item.toJson()).toList(),
    };
  }
}
