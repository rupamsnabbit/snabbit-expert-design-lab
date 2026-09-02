import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:snabbit_runner/effects/blinking.dart';
import 'package:snabbit_runner/payout/bonus/models/festive_bonus.dart';
import 'package:snabbit_runner/services/custom_text/custom_text.dart';
import 'package:snabbit_runner/services/payout_http.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/constants.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/widgets/common_app_bar.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';

import '../widgets/shift_details.dart';

class FestiveBonusScreen extends StatefulWidget {
  static const String routeName = '/festive-bonus';

  const FestiveBonusScreen({super.key});

  @override
  State<FestiveBonusScreen> createState() => _FestiveBonusScreenState();
}

class _FestiveBonusScreenState extends State<FestiveBonusScreen> {
  bool loading = true;
  FestiveBonus? festiveBonus;

  @override
  void initState() {
    initProcess().then((_) {
      loading = false;
      if (mounted) setState(() {});
    });
    super.initState();
  }

  Future<void> initProcess() async {
    try {
      final response = await PayoutHttp.getFestiveBonus();
      if (response != null) {
        festiveBonus = FestiveBonus.fromJson(response.data);
      }
    } catch(e) {
      // DO NOTHING
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F6F8),
      appBar: const CommonAppBar(),
      body: loading
          ? const Center(child: CupertinoActivityIndicator())
          : festiveBonus == null
              ? const Center(child: Text("Error loading page. Try later"))
              : Column(
                  children: [
                    if (festiveBonus?.bonusInfo?.status == PaymentState.pending)
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          RemoteImageHandler(
                            imageUrl: festiveBonus?.bonusInfo?.bg?.url ?? "",
                            fit: BoxFit.cover,
                            width: 1.sw,
                            errorWidget: Container(
                              width: 1.sw,
                              height: festiveBonus?.bonusInfo?.bg?.height?.h,
                              color: festiveBonus?.bonusInfo?.bg?.color,
                            ),
                          ),
                          if (festiveBonus?.bonusInfo != null)
                            Positioned.fill(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CustomText(
                                      textData: festiveBonus?.bonusInfo?.title,
                                    ),
                                    Padding(
                                        padding: EdgeInsets.only(top: 17.h)),
                                    CustomText(
                                      textData:
                                          festiveBonus?.bonusInfo?.paymentDate,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      )
                    else if (festiveBonus?.bonusInfo?.status ==
                        PaymentState.earned)
                      Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          RemoteImageHandler(
                            imageUrl: festiveBonus?.bonusInfo?.bg?.url ?? "",
                            fit: BoxFit.cover,
                            width: 1.sw,
                            errorWidget: Container(
                              width: 1.sw,
                              height: festiveBonus?.bonusInfo?.bg?.height?.h,
                              color: festiveBonus?.bonusInfo?.bg?.color,
                            ),
                          ),
                          Positioned.fill(
                            child: RemoteImageHandler(
                              imageUrl:
                                  festiveBonus?.bonusInfo?.icon?.url ?? "",
                              fit: BoxFit.cover,
                              width: 1.sw,
                              repeat: false,
                            ),
                          ),
                          if (festiveBonus?.bonusInfo != null)
                            Positioned.fill(
                              left: 50.w,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  FittedBox(
                                    child: CustomText(
                                      textData: festiveBonus?.bonusInfo?.title,
                                    ),
                                  ),
                                  FittedBox(
                                    child: CustomText(
                                      textData:
                                          festiveBonus?.bonusInfo?.paymentDate,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 16.w, vertical: 20.h),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 1.sw,
                                    decoration: BoxDecoration(
                                      color: AppColors.n0,
                                      borderRadius: BorderRadius.circular(10.r),
                                    ),
                                    padding: EdgeInsets.all(24.r),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        ...festiveBonus
                                                ?.paymentSummary?.elements
                                                ?.map((e) {
                                              return Padding(
                                                padding: EdgeInsets.only(
                                                    bottom: 12.h),
                                                child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          CustomText(
                                                              textData:
                                                                  e.title),
                                                          if (e.subtitle !=
                                                              null)
                                                            CustomText(
                                                                textData:
                                                                    e.subtitle),
                                                        ],
                                                      ),
                                                    ),
                                                    CustomText(
                                                        textData: e.value),
                                                  ],
                                                ),
                                              );
                                            }).toList() ??
                                            [],
                                        Divider(
                                          color: const Color(0xffD0D0D0),
                                          height: 1.h,
                                        ),
                                        SizedBox(height: 12.h),
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: CustomText(
                                                textData: festiveBonus
                                                    ?.paymentSummary
                                                    ?.total
                                                    ?.title,
                                              ),
                                            ),
                                            CustomText(
                                              textData: festiveBonus
                                                  ?.paymentSummary
                                                  ?.total
                                                  ?.value,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding:
                                        EdgeInsets.symmetric(vertical: 20.h),
                                    child: CustomText(
                                      textData: festiveBonus
                                          ?.dateWiseDeductions?.trackerTitle,
                                    ),
                                  ),
                                  // Add calendar widget for demo
                                  CalendarSectionView(
                                    dateWiseDeductions:
                                        festiveBonus?.dateWiseDeductions,
                                  ),
                                  Padding(
                                    padding:
                                        EdgeInsets.symmetric(vertical: 20.h),
                                    child: CustomText(
                                      textData: festiveBonus
                                          ?.dateWiseDeductions?.breakdownTitle,
                                    ),
                                  ),
                                  ...festiveBonus?.dateWiseDeductions?.days
                                          ?.map((e) {
                                        return DailyBreakdown(e: e);
                                      }).toList() ??
                                      [],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class DateRangeCalendar extends StatelessWidget {
  final List<DeductionDay>? days;

  const DateRangeCalendar({
    super.key,
    required this.days,
  });

  List<DeductionDay> get sortedDays {
    if (days == null || days!.isEmpty) return [];

    // Filter out days with null dates and sort them by date
    return days!.where((day) => day.date != null).toList()
      ..sort((a, b) => a.date!.compareTo(b.date!));
  }

  @override
  Widget build(BuildContext context) {
    if (sortedDays.isEmpty) {
      return const SizedBox();
    }

    return Column(
      children: [
        _buildWeekdayHeaders(context),
        Padding(
          padding: EdgeInsets.only(top: 20.h, bottom: 7.h),
          child: Divider(
            color: AppColors.n30,
            height: 1.h,
          ),
        ),
        _buildDateGrid(context),
      ],
    );
  }

  Widget _buildWeekdayHeaders(BuildContext context) {
    if (sortedDays.isEmpty) return const SizedBox();

    List<String> weekdays = [];

    // Start from the first day's weekday and create 7 days
    DateTime current = sortedDays.first.date!;
    for (int i = 0; i < 7; i++) {
      weekdays.add(DateFormat('EEE').format(current).toUpperCase());
      current = current.add(const Duration(days: 1));
    }

    return Row(
      children: weekdays.map((weekday) {
        return Expanded(
          child: Text(
            weekday,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(color: const Color(0xff6D7783)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDateGrid(BuildContext context) {
    if (sortedDays.isEmpty) return const SizedBox();

    List<Widget> rows = [];
    List<Widget> currentWeek = [];

    // Assuming consecutive dates, create date range from first to last
    DateTime startDate = sortedDays.first.date!;
    DateTime endDate = sortedDays.last.date!;
    DateTime current = startDate;

    // Create a map for quick lookup of DeductionDay by date
    Map<String, DeductionDay> dayMap = {};
    for (DeductionDay day in sortedDays) {
      if (day.date != null) {
        String dateKey =
            '${day.date!.year}-${day.date!.month}-${day.date!.day}';
        dayMap[dateKey] = day;
      }
    }

    // Fill the date grid with all dates in the range
    while (current.isBefore(endDate.add(const Duration(days: 1)))) {
      String dateKey = '${current.year}-${current.month}-${current.day}';
      DeductionDay? dayData = dayMap[dateKey];

      final textColor = [
        DeductionDayStatus.critical,
        DeductionDayStatus.important,
        DeductionDayStatus.general,
      ].contains(dayData?.status)
          ? AppColors.n80
          : AppColors.n50;

      final isLineThrough = [
        DeductionDayStatus.badShift,
      ].contains(dayData?.status);

      currentWeek.add(
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  current.day == 1 ? monthFormatVisual1.format(current) : "",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.n80,
                        decoration: TextDecoration.lineThrough,
                        decorationColor: AppColors.n90,
                      ),
                ),
                SizedBox(height: 1.23.h),
                Stack(
                  children: [
                    Text(
                      current.day.toString(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                    ),
                    Positioned.fill(
                      child: Align(
                        alignment: Alignment.center,
                        child: Container(
                          height: 1.h,
                          color: isLineThrough
                              ? AppColors.n90
                              : Colors.transparent,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6.h),
                Container(
                  height: dayData?.icon?.height ?? 13.h,
                  padding: EdgeInsets.symmetric(horizontal: 4.w),
                  child: (dayData?.value != null)
                      ? FittedBox(
                          child: CustomText(
                            textData: dayData?.value,
                          ),
                        )
                      : (dayData?.icon != null)
                          ? BlinkingWidget(
                              blink: dayData?.isBlinking ?? false,
                              child: RemoteImageHandler(
                                imageUrl: dayData?.icon?.url ?? "",
                                height: dayData?.icon?.height,
                                errorWidget: Container(
                                  height: dayData?.icon?.height,
                                  width: dayData?.icon?.height,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: dayData?.icon?.color,
                                  ),
                                ),
                              ),
                            )
                          : const Text(''),
                ),
              ],
            ),
          ),
        ),
      );

      // If we have 7 days or reached the end, create a row
      if (currentWeek.length == 7 || current.isAtSameMomentAs(endDate)) {
        // Fill remaining slots if needed
        while (currentWeek.length < 7) {
          currentWeek.add(
            Expanded(
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 8.h),
                child: const Text(''),
              ),
            ),
          );
        }

        rows.add(
          SizedBox(height: 53.h, child: Row(children: List.from(currentWeek))),
        );
        currentWeek.clear();
      }

      current = current.add(const Duration(days: 1));
    }

    return Column(children: rows);
  }
}

class DailyBreakdown extends StatelessWidget {
  final DeductionDay e;

  const DailyBreakdown({
    super.key,
    required this.e,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1.sw,
      decoration: BoxDecoration(
        color: AppColors.n0,
        border: Border.all(color: AppColors.n40),
        borderRadius: BorderRadius.circular(12.r),
      ),
      padding: EdgeInsets.all(16.r),
      margin: EdgeInsets.only(bottom: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (e.date != null)
                Expanded(
                  child: Text(
                    dateFormatVisual4.format(e.date!),
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              if (e.value != null)
                CustomText(
                  textData: e.value,
                )
              else if (e.icon != null)
                BlinkingWidget(
                  blink: e.isBlinking ?? false,
                  child: RemoteImageHandler(
                    imageUrl: e.icon?.url ?? "",
                    height: e.icon?.height,
                  ),
                ),
            ],
          ),
          SizedBox(height: 12.h),
          Container(
            width: 1.sw,
            decoration: BoxDecoration(
              color: AppColors.n20,
              borderRadius: BorderRadius.circular(8.r),
            ),
            padding: EdgeInsets.all(8.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomText(textData: e.details?.title),
                ...e.details?.items?.map((e1) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (e1.icon != null)
                                Padding(
                                  padding: EdgeInsets.only(right: 4.w),
                                  child: RemoteImageHandler(
                                    imageUrl: e1.icon?.url ?? "",
                                    height: e1.icon?.height,
                                  ),
                                ),
                              Expanded(
                                child: CustomText(
                                  textData: e1.title,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          ...e1.items?.map((e2) {
                                return Padding(
                                  padding: EdgeInsets.only(left: 16.w),
                                  child: CustomText(
                                    textData: e2.title,
                                  ),
                                );
                              }).toList() ??
                              []
                        ],
                      );
                    }).toList() ??
                    [],
              ],
            ),
          )
        ],
      ),
    );
  }
}

class CalendarSectionView extends StatelessWidget {
  final DateWiseDeductions? dateWiseDeductions;

  const CalendarSectionView({
    super.key,
    this.dateWiseDeductions,
  });

  @override
  Widget build(BuildContext context) {
    if (dateWiseDeductions == null) return const SizedBox();
    return Container(
      margin: EdgeInsets.only(bottom: 20.h),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppColors.n0,
        border: Border.all(color: AppColors.n40),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (dateWiseDeductions?.goodShift != null)
                Expanded(
                  child: ShiftDetails(
                    trackerInfo: dateWiseDeductions?.goodShift,
                    bgColor: AppColors.g0,
                  ),
                ),
              SizedBox(width: 12.w),
              if (dateWiseDeductions?.badShift != null)
                Expanded(
                  child: ShiftDetails(
                    trackerInfo: dateWiseDeductions?.badShift,
                    bgColor: AppColors.r0,
                  ),
                ),
            ],
          ),
          SizedBox(height: 23.h),
          DateRangeCalendar(
            days: dateWiseDeductions?.days,
          ),
        ],
      ),
    );
  }
}
