import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/shift_performance_details.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/widgets/payout/shift_earning_summary_item.dart';
import 'package:snabbit_runner/widgets/payout/shift_insights_list.dart';

enum ShiftPerformance {
  goodShift,
  badShift;

  static ShiftPerformance fromString(String? status) {
    switch (status) {
      case 'goodShift':
        return ShiftPerformance.goodShift;
      case 'badShift':
        return ShiftPerformance.badShift;
      default:
        return ShiftPerformance.goodShift;
    }
  }
}

class ShiftPerformanceBreakdownCard extends StatefulWidget {
  const ShiftPerformanceBreakdownCard({
    super.key,
    required this.shiftPerformanceDetails,
  });

  final ShiftPerformanceDetails shiftPerformanceDetails;

  @override
  State<ShiftPerformanceBreakdownCard> createState() =>
      _ShiftPerformanceBreakdownCardState();
}

class _ShiftPerformanceBreakdownCardState
    extends State<ShiftPerformanceBreakdownCard> {
  bool init = true;
  late LanguageProvider languageProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
    }
  }

  bool get isGoodShift =>
      widget.shiftPerformanceDetails.shiftPerformance ==
      ShiftPerformance.goodShift;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          EdgeInsets.only(left: 20.r, right: 20.r, top: 20.r, bottom: 0.r),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8.r), color: AppColors.n0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            languageProvider.getMessage(
              widget.shiftPerformanceDetails.title,
              widget.shiftPerformanceDetails.title,
            ),
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: isGoodShift ? AppColors.g40 : Color(0xffF0A400),
                  fontSize: 16.sp,
                ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 12.h),
          ShiftInsightsList(
            shiftInsightList: widget.shiftPerformanceDetails.shiftInsightList,
            showDescription: false,
            childAspectRatio: 1.0,
          ),
          SizedBox(height: 16.h),
          Divider(
            height: 0,
            thickness: 1.r,
            color: AppColors.n50,
          ),
          SizedBox(height: 16.h),
          Text(
            languageProvider.getMessage(widget.shiftPerformanceDetails.subTitle,
                widget.shiftPerformanceDetails.subTitle),
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600, color: AppColors.n90),
          ),
          SizedBox(height: 12.h),
          ListView.separated(
            padding: EdgeInsets.zero,
            itemCount:
                widget.shiftPerformanceDetails.shiftEarningSummaryList.length,
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              return ShiftEarningSummaryItem(
                shiftEarningSummary: widget
                    .shiftPerformanceDetails.shiftEarningSummaryList[index],
              );
            },
            separatorBuilder: (_, __) {
              return SizedBox(height: 10.h);
            },
          ),
          SizedBox(height: 12.h),
          if (widget.shiftPerformanceDetails.jobDenialDetails?.isNotEmpty ??
              false) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widget.shiftPerformanceDetails.jobDenialDetails
                  ?.map((reason) => Padding(
                padding: EdgeInsets.only(bottom: 8.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• ',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.n80),
                    ),
                    Expanded(
                      child: Text(
                        reason,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppColors.n80),
                      ),
                    ),
                  ],
                ),
              ))
                  .toList() ??
                  [],
            ),
            SizedBox(height: 16.h),
          ],
        ],
      ),
    );
  }
}
