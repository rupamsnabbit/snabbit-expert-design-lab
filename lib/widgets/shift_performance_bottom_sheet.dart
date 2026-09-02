import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/shift_config.dart';
import 'package:snabbit_runner/models/today_shift_performance_model.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/runner_rt_data.dart';
import 'package:snabbit_runner/services/clevertap.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/extensions/cdn_extensions.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';
import 'package:snabbit_runner/widgets/common_bottomsheet_setup.dart';
import 'package:snabbit_runner/widgets/payout/shift_insights_list.dart';
import 'package:snabbit_runner/widgets/payout/shift_performance_breakdown_card.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';

void showShiftPerformanceBottomSheet(
  BuildContext context,
  TodayShiftPerformance todayShiftPerformance,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return CommonBottomSheetSetup(
        bgColor: todayShiftPerformance.getBackgroundColor(),
        horizontalPadding: 0,
        showDragHandle: false,
        bottomPadding: 0,
        child: ShiftPerformanceBottomSheetContent(
          todayShiftPerformance: todayShiftPerformance,
        ),
      );
    },
  );
}

class ShiftPerformanceBottomSheetContent extends StatefulWidget {
  const ShiftPerformanceBottomSheetContent({
    super.key,
    required this.todayShiftPerformance,
  });

  final TodayShiftPerformance todayShiftPerformance;

  @override
  State<ShiftPerformanceBottomSheetContent> createState() =>
      _ShiftPerformanceBottomSheetContentState();
}

class _ShiftPerformanceBottomSheetContentState
    extends State<ShiftPerformanceBottomSheetContent> {
  bool init = true;
  late LanguageProvider languageProvider;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<RunnerRtDataProvider>(context, listen: false)
          .markShiftPerformanceBottomSheetAsShown();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      _logEvent();
    }
  }

  void _logEvent() {
    try {
      ClevertapSetup.logEvent(
        TrackingEvents.shiftPerformanceBottomSheetShown,
        {"time": DateTime.now().toIso8601String()},
      );
    } catch (e) {}
  }

  bool get isGoodShift =>
      widget.todayShiftPerformance.shiftPerformanceDetails.shiftPerformance ==
      ShiftPerformance.goodShift;

  bool get isBadShift => !isGoodShift;

  bool get showMinGOnly =>
      widget.todayShiftPerformance.shiftPerformanceDetails.shiftPerformance ==
          ShiftPerformance.goodShift &&
      widget.todayShiftPerformance.shiftPerformanceDetails.shiftConfig
              .shiftEarningType ==
          GoodShiftStatusEnum.ming;

  double get childAspectRatio {
    final allWithoutSubtitle = widget
        .todayShiftPerformance.shiftPerformanceDetails.shiftInsightList
        .every((insight) => insight.subTitle == null);
    return allWithoutSubtitle ? 1.0 : 0.7;
  }

  double? get minGAmount =>
      widget.todayShiftPerformance.shiftPerformanceDetails.shiftConfig.ming;

  double? get basePayAmount =>
      widget.todayShiftPerformance.shiftPerformanceDetails.shiftConfig.basePay;

  double? get higherBasePayAmount => widget
      .todayShiftPerformance.shiftPerformanceDetails.shiftConfig.higherBasePay;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: 0.75.sh,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: RemoteImageHandler(
                imageUrl: widget.todayShiftPerformance.widgetData.bgImageUrl.cdn,
                fit: BoxFit.fill,
                width: 1.sw,
                height: 1.sh,
              ),
            ),
            SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Column(
                  children: [
                    SizedBox(height: 20.h),
                    // Top icon
                    RemoteImageHandler(
                      imageUrl:
                          widget.todayShiftPerformance.widgetData.imageUrl.cdn,
                      height: 80.h,
                      fit: BoxFit.contain,
                    ),
                    SizedBox(height: 16.h),
                    // Title
                    Text(
                      widget.todayShiftPerformance
                          .getHeaderMessage(languageProvider: languageProvider),
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: AppColors.n0,
                                fontWeight: FontWeight.w700,
                                fontSize: 24.sp,
                                height: (32 / 24).sp,
                              ),
                      textAlign: TextAlign.center,
                    ),

                    /// waived off widget
                    if (isBadShift &&
                        widget.todayShiftPerformance.shiftPerformanceDetails
                                .shiftConfig.waivedOffStatus ==
                            BadShiftStatusEnum.waivedOff)
                      _waivedOffWidget(context),
                    SizedBox(height: 16.h),

                    /// good pay min g widget
                    if (isGoodShift) _goodShiftWidget(context),
                    SizedBox(height: 24.h),

                    Container(
                      padding: EdgeInsets.only(
                        left: 12.w,
                        right: 12.w,
                        top: 12.h,
                        bottom: 12.h,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12.r),
                        color: AppColors.n0,
                      ),
                      child: ShiftInsightsList(
                        shiftInsightList: widget.todayShiftPerformance
                            .shiftPerformanceDetails.shiftInsightList,
                        showDescription: true,
                        childAspectRatio: childAspectRatio,
                      ),
                    ),

                    SizedBox(height: 32.h),

                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 36.w),
                      child: Text(
                        widget.todayShiftPerformance.getFooterMessage(
                            languageProvider: languageProvider),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.n0,
                              fontSize: 14.sp,
                              height: (20 / 14).sp,
                              fontWeight: FontWeight.w500,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(height: 50.h),

                    SizedBox(
                      width: 1.sw,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.n90,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                        ),
                        child: Text(
                          languageProvider.getMessage(
                            'confirm',
                            'Confirm',
                          ),
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.n0,
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.24,
                                  ),
                        ),
                      ),
                    ),
                    SizedBox(height: 40.h),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Container _goodShiftWidget(
    BuildContext context,
  ) {
    bool isMinGOnly = showMinGOnly;

    return Container(
      margin: EdgeInsets.only(top: 16.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.n0, // White card
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          // Left section with emoji and text
          Expanded(
            flex: 3,
            child: Row(
              children: [
                RemoteImageHandler(
                  imageUrl: widget.todayShiftPerformance.shiftPerformanceDetails
                      .shiftConfig.imageUrl.cdn,
                  height: 30.h,
                  fit: BoxFit.contain,
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.todayShiftPerformance
                            .getGoodShiftRateCardMessage(
                                languageProvider: languageProvider),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Color(0xFF101840),
                              fontSize: 15.sp,
                              height: (18 / 15).sp,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          // Right section with pay comparison
          GoodShiftAmountSection(
            isMinGOnly: isMinGOnly,
            minGAmount: minGAmount,
            higherBasePayAmount: higherBasePayAmount,
            basePayAmount: basePayAmount,
            basePayUnit: languageProvider.getMessage(
              "per_hour",
              "per hour",
            ),
            bgColor: Color(0xFFF3F3F5),
          ),
        ],
      ),
    );
  }

  Widget _waivedOffWidget(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: 5.h),
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Color(0xFF2F2F2F), // Dark gray background
            borderRadius: BorderRadius.circular(4.r),
          ),
          child: Text(
            languageProvider.getMessage(
              "today_shift_waived_off",
              "Waived off as its your first time",
            ),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.n0,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class GoodShiftAmountSection extends StatelessWidget {
  const GoodShiftAmountSection({
    super.key,
    required this.isMinGOnly,
    required this.minGAmount,
    required this.higherBasePayAmount,
    required this.basePayAmount,
    this.hideBasePayAmount = false,
    required this.bgColor,
    required this.basePayUnit,
  });

  final bool hideBasePayAmount;
  final bool isMinGOnly;
  final double? minGAmount;
  final double? higherBasePayAmount;
  final double? basePayAmount;
  final Color bgColor;
  final String basePayUnit;

  @override
  Widget build(BuildContext context) {
    if ((isMinGOnly && minGAmount == null) ||
        (higherBasePayAmount == null &&
            basePayAmount == null &&
            isMinGOnly == false)) {
      return SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6.r),
      ),
      padding: hideBasePayAmount
          ? EdgeInsets.symmetric(horizontal: 6.w, vertical: 6.h)
          : isMinGOnly
              ? EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h)
              : EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          isMinGOnly && minGAmount != null
              ? PriceWidget(
                  price: minGAmount!,
                  textStyle:
                      Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: hideBasePayAmount
                                ? AppColors.n0
                                : Color(0xFF5FB965),
                            fontSize: 24.sp,
                            height: 1.0,
                            fontWeight: FontWeight.w800,
                            fontStyle: FontStyle.italic,
                          ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    if (higherBasePayAmount != null)
                      PriceWidget(
                        price: higherBasePayAmount!,
                        textStyle:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: hideBasePayAmount
                                      ? AppColors.n0
                                      : Color(0xFF5FB965),
                                  fontSize: 24.sp,
                                  height: 1.0,
                                  fontWeight: FontWeight.w800,
                                  fontStyle: FontStyle.italic,
                                ),
                      ),
                    if (!hideBasePayAmount) SizedBox(width: 4.w),
                    if (!hideBasePayAmount)
                      if (basePayAmount != null)
                        PriceWidget(
                          price: basePayAmount!,
                          textStyle: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: Color(0xFF6B7088),
                                fontSize: 12.sp,
                                height: 1.0,
                                fontWeight: FontWeight.w800,
                                decoration: TextDecoration.lineThrough,
                              ),
                        ),
                  ],
                ),
          isMinGOnly
              ? SizedBox.shrink()
              : Padding(
                  padding: EdgeInsets.only(left: hideBasePayAmount ? 8.w : 2.w),
                  child: Text(
                    basePayUnit,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: hideBasePayAmount
                              ? AppColors.n0
                              : Color(0xFF6B7088),
                          fontSize: 8.sp,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
        ],
      ),
    );
  }
}

class PriceWidget extends StatelessWidget {
  final double price;
  final TextStyle? textStyle;
  final String currencySymbol;
  final double superscriptSizeRatio;

  const PriceWidget({
    Key? key,
    required this.price,
    this.textStyle,
    this.currencySymbol = '₹',
    this.superscriptSizeRatio = 0.75,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final baseStyle = textStyle ??
        const TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.bold,
          color: Color(0xFF5CB85C), // Green color
        );

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start, // Aligns to top
      children: [
        Text(
          currencySymbol,
          style: baseStyle.copyWith(
            fontSize: (baseStyle.fontSize ?? 48) * superscriptSizeRatio,
          ),
        ),
        // Price value
        Text(
          formatIndianCurrency(price.toInt(), showSymbol: false),
          style: baseStyle,
        ),
      ],
    );
  }
}
