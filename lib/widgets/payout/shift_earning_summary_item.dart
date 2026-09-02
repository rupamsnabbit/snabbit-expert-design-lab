import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/shift_earning_summary.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/widgets/payout/shift_performance_breakdown_card.dart';

class ShiftEarningSummaryItem extends StatefulWidget {
  const ShiftEarningSummaryItem({
    super.key,
    required this.shiftEarningSummary,
  });

  final ShiftEarningSummary shiftEarningSummary;

  @override
  State<ShiftEarningSummaryItem> createState() =>
      _ShiftEarningSummaryItemState();
}

class _ShiftEarningSummaryItemState extends State<ShiftEarningSummaryItem> {
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
      widget.shiftEarningSummary.shiftPerformance == ShiftPerformance.goodShift;

  Color get bodyColor => isGoodShift ? AppColors.g10 : Color(0xffFFF4DB);

  Color get textColor => (widget.shiftEarningSummary.isActive != null &&
          widget.shiftEarningSummary.isActive!)
      ? AppColors.n90
      : AppColors.n50;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 11.h),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10.r),
          border: (widget.shiftEarningSummary.isActive != null &&
                  widget.shiftEarningSummary.isActive!)
              ? Border.all(
                  color: isGoodShift ? Color(0xFF1EBB80) : Color(0xffFFAE00),
                  width: 2.r,
                )
              : null,
          color: (widget.shiftEarningSummary.isActive != null &&
                  widget.shiftEarningSummary.isActive!)
              ? bodyColor
              : AppColors.n20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: languageProvider.getMessage(
                        widget.shiftEarningSummary.shiftPerformanceTitle ?? '',
                        widget.shiftEarningSummary.shiftPerformanceTitle ?? ''),
                    style: Theme.of(context)
                        .textTheme
                        .displaySmall
                        ?.copyWith(color: textColor),
                  ),
                  if (widget.shiftEarningSummary.breakdown != null &&
                      widget.shiftEarningSummary.breakdown!.isNotEmpty) ...[
                    const TextSpan(text: ' '),
                    TextSpan(
                      text: languageProvider.getMessage(
                          widget.shiftEarningSummary.breakdown ?? '',
                          widget.shiftEarningSummary.breakdown ?? ''),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 12.sp,
                            color: textColor,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(width: 16.w),
          widget.shiftEarningSummary.amount != null
              ? Text(
                  formatIndianCurrency(widget.shiftEarningSummary.amount),
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        color: textColor,
                        fontSize: 16.sp,
                      ),
                )
              : SizedBox(),
        ],
      ),
    );
  }
}
