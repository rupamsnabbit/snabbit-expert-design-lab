import 'package:flutter/material.dart';

import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/shift_config.dart';
import 'package:snabbit_runner/models/today_shift_performance_model.dart';
import 'package:snabbit_runner/pages/payout/daily_earnings_state.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/runner_rt_data.dart';
import 'package:snabbit_runner/services/custom_text/custom_text.dart';
import 'package:snabbit_runner/utils/extensions/cdn_extensions.dart';
import 'package:snabbit_runner/widgets/payout/current_period_view.dart';
import 'package:snabbit_runner/widgets/payout/shift_performance_breakdown_card.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';
import 'package:snabbit_runner/widgets/shift_performance_bottom_sheet.dart';

class TodayShiftPerformanceWidget extends StatefulWidget {
  const TodayShiftPerformanceWidget({super.key});

  @override
  State<TodayShiftPerformanceWidget> createState() =>
      _TodayShiftPerformanceWidgetState();
}

class _TodayShiftPerformanceWidgetState
    extends State<TodayShiftPerformanceWidget> {
  bool init = true;
  bool loading = true;
  late LanguageProvider languageProvider;
  late RunnerRtDataProvider runnerRtDataProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      runnerRtDataProvider =
          Provider.of<RunnerRtDataProvider>(context, listen: true);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        initProcess().then((_) {
          loading = false;
          if (mounted) {
            setState(() {});
          }

          TodayShiftPerformance? todayShiftPerformance =
              runnerRtDataProvider.todayShiftPerformance;
          if (todayShiftPerformance != null) {
            if (runnerRtDataProvider.shouldShowShiftPerformanceBottomSheet()) {
              showShiftPerformanceBottomSheet(
                context,
                todayShiftPerformance,
              );
            }
          }
        });
      });
    }
  }

  Future<void> initProcess() async {
    try {
      await runnerRtDataProvider.getTodayShiftPerformance();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    TodayShiftPerformance? todayShiftPerformance =
        runnerRtDataProvider.todayShiftPerformance;
    if (todayShiftPerformance == null) {
      return SizedBox.shrink();
    }

    bool isWaivedOff =
        todayShiftPerformance.shiftPerformanceDetails.shiftPerformance ==
                ShiftPerformance.badShift &&
            todayShiftPerformance
                    .shiftPerformanceDetails.shiftConfig.waivedOffStatus ==
                BadShiftStatusEnum.waivedOff;

    bool showMinGOnly =
        todayShiftPerformance.shiftPerformanceDetails.shiftPerformance ==
                ShiftPerformance.goodShift &&
            todayShiftPerformance
                    .shiftPerformanceDetails.shiftConfig.shiftEarningType ==
                GoodShiftStatusEnum.ming;

    double? minGAmount =
        todayShiftPerformance.shiftPerformanceDetails.shiftConfig.ming;

    double? basePayAmount =
        todayShiftPerformance.shiftPerformanceDetails.shiftConfig.basePay;
    double? higherBasePayAmount =
        todayShiftPerformance.shiftPerformanceDetails.shiftConfig.higherBasePay;

    bool showSubtitle =
        todayShiftPerformance.widgetData.bannerSubtitle != null &&
            todayShiftPerformance.widgetData.bannerSubtitle?.isNotEmpty == true;

    return GestureDetector(
      onTap: () {
        CurrentPeriodProvider periodProvider =
            Provider.of<CurrentPeriodProvider>(context, listen: false);
        final today = DateTime.now();
        periodProvider.currentDate = DateTime(today.year, today.month, today.day);

        Navigator.pushNamed(
          context,
          DailyEarningState.routeName,
        );
      },
      child: Container(
        width: 1.sw,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.r),
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            Positioned.fill(
              child: RemoteImageHandler(
                imageUrl: todayShiftPerformance.widgetData.bannerImageUrl.cdn,
                fit: BoxFit.fitWidth,
                width: 1.sw,
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                  left: 12.w, right: 12.w, top: 16.h, bottom: 16.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left side - Image and Badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Column(
                        children: [
                          // Screenshot/Image placeholder
                          RemoteImageHandler(
                            imageUrl: todayShiftPerformance.widgetData.imageUrl.cdn,
                            width: 60.w,
                            fit: BoxFit.cover,
                          ),

                          // WAIVED OFF badge
                          if (isWaivedOff)
                            Transform.translate(
                              offset: Offset(0, -10.h),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 4.w,
                                  vertical: 8.h,
                                ),
                                decoration: BoxDecoration(
                                  color: Color(0xFF2F2F2F),
                                  borderRadius: BorderRadius.circular(4.r),
                                ),
                                child: Text(
                                  languageProvider.getMessage(
                                    "waived_off",
                                    "WAIVED\nOFF",
                                  ),
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: AppColors.n0,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 10.sp,
                                        height: (11 / 10).sp,
                                      ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(width: 12.w), // Right side - Text content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                todayShiftPerformance.getBannerTitleMessage(
                                    languageProvider: languageProvider),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15.sp,
                                      height: (18 / 15).sp,
                                      color: AppColors.n0,
                                    ),
                              ),
                            ),
                            if (todayShiftPerformance
                                    .shiftPerformanceDetails.shiftPerformance !=
                                ShiftPerformance.badShift)
                              Padding(
                                padding: EdgeInsets.only(left: 12.w),
                                child: GoodShiftAmountSection(
                                  isMinGOnly: showMinGOnly,
                                  minGAmount: minGAmount,
                                  higherBasePayAmount: higherBasePayAmount,
                                  basePayAmount: basePayAmount,
                                  hideBasePayAmount: true,
                                  basePayUnit: languageProvider.getMessage(
                                    "per_hour",
                                    "per hour",
                                  ),
                                  bgColor: Color(0xFF3F7956),
                                ),
                              )
                          ],
                        ),
                        if (showSubtitle) SizedBox(height: 4.h),
                        if (showSubtitle)
                          CustomTextNS(
                            null,
                            textDataList:
                                todayShiftPerformance.widgetData.bannerSubtitle,
                            separator: ", ",
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15.sp,
                                      height: (18 / 15).sp,
                                      color: Color(0xFFC3C3C3),
                                    ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (showSubtitle) SizedBox(height: 8.h),

                        if (showSubtitle == false) SizedBox(height: 16.h),

                        // View earnings button
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 4.h,
                          ),
                          decoration: BoxDecoration(
                            color: Color(0xFF101840),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                languageProvider.getMessage(
                                  "today_shift_view_earnings",
                                  "View today's earnings",
                                ),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppColors.n0,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12.sp,
                                      height: (18 / 12).sp,
                                    ),
                              ),
                              SizedBox(width: 4.w),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 10.sp,
                                color: AppColors.n0,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

