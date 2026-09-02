import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/attendance.dart';
import 'package:snabbit_runner/providers/payout.dart';
import 'package:snabbit_runner/services/payout_http.dart';
import 'package:snabbit_runner/widgets/common_app_bar.dart';
import 'package:snabbit_runner/widgets/payout/current_period_view.dart';
import 'package:snabbit_runner/widgets/payout/custom_progress_bar.dart';
import 'package:snabbit_runner/widgets/payout/payout_section_container.dart';

import '../../utils/colors.dart';
import '../../utils/common_methods.dart';
import '../../utils/enums.dart';
import '../../widgets/drawer/drawer_menu.dart';

class Attendance extends StatefulWidget {
  static const String routeName = "/attendance";

  const Attendance({super.key});

  @override
  State<Attendance> createState() => _AttendanceState();
}

class _AttendanceState extends State<Attendance> {
  bool init = true;
  bool loading = true;
  String? error;
  late PayoutProvider payoutProvider;
  late CurrentPeriodProvider currentPeriodProvider;

  // DateTime selectedDate = DateTime.now();
  // DateTime firstDayOfRange = DateTime.now();
  // DateTime lastDayOfRange = DateTime.now();
  final daysOfWeek = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
  List<DateTime> daysToDisplay = [];
  int firstWeekdayOffset = 0;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      payoutProvider = Provider.of<PayoutProvider>(context, listen: true);
      currentPeriodProvider =
          Provider.of<CurrentPeriodProvider>(context, listen: true);
      getDaysInMonth(currentPeriodProvider.monthStartDate);
      initProcess().then((_) {
        loading = false;
        if (mounted) {
          setState(() {});
        }
      });
    }
    super.didChangeDependencies();
  }

  Future<void> initProcess() async {
    Response? response = await PayoutHttp.getAttendance(
        start: currentPeriodProvider.monthStartDate,
        end: currentPeriodProvider.monthEndDate);
    if (response != null) {
      error = null;
      payoutProvider.setAttendance(response.data);
    } else {
      error = "Something went wrong";
      payoutProvider.setAttendance(null);
    }

    if (daysToDisplay.isNotEmpty) {
      firstWeekdayOffset = daysToDisplay.first.weekday - 1;
    } else {
      firstWeekdayOffset = 0;
    }
  }

  void getDaysInMonth(DateTime date) {
    final daysInMonth = DateTime(date.year, date.month + 1, 0).day;
    // firstDayOfRange = DateTime(date.year, date.month, 1);
    // lastDayOfRange = firstDayOfRange.add(Duration(days: daysInMonth - 1));
    daysToDisplay = List.generate(
        daysInMonth,
        (index) =>
            currentPeriodProvider.monthStartDate.add(Duration(days: index)));
  }

  bool isSameDate(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  DailyAttendance? getCorrespondingDailyData(DateTime date) {
    try {
      return payoutProvider.attendance!.dailyAttendanceList
          .firstWhere((e) => isSameDate(e.date, date));
    } catch (e) {
      return null;
    }
  }

  Color getDateColor(DateTime date) {
    DailyAttendance? dailyAttendance = getCorrespondingDailyData(date);
    if (dailyAttendance?.status == DailyAttendanceStatus.present) {
      return AppColors.g40;
    } else if (dailyAttendance?.status ==
        DailyAttendanceStatus.falseAttendance) {
      return AppColors.n90;
    } else if (dailyAttendance?.status == DailyAttendanceStatus.absent) {
      return AppColors.r40;
    } else {
      return AppColors.n30;
    }
  }

  double getProgress() {
    try {
      return (payoutProvider.attendance?.presentDays ?? 0) /
          daysInCurrentMonth(currentPeriodProvider.monthStartDate);
    } catch (e) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F6F8),
      appBar: CommonAppBar(
        title: Text(
          "Attendance",
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        centerTitle: true,
      ),
      body: loading
          ? const Center(
              child: CupertinoActivityIndicator(),
            )
          : Padding(
              padding: EdgeInsets.symmetric(
                vertical: 20.h,
                horizontal: 16.w,
              ),
              child: SingleChildScrollView(
                child: PayoutSectionContainer(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CurrentPeriodView(
                          viewType: PayoutPeriod.monthly,
                          onChanged: () async {
                            getDaysInMonth(
                                currentPeriodProvider.monthStartDate);
                            setState(() {
                              loading = true;
                            });
                            await initProcess();
                            setState(() {
                              loading = false;
                            });
                          }),
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 4.h),
                        child: const Divider(
                          color: AppColors.n30,
                        ),
                      ),
                      SizedBox(
                        width: 1.sw,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text:
                                        "${payoutProvider.attendance?.presentDays ?? 0}/${daysInCurrentMonth(currentPeriodProvider.monthStartDate)}",
                                    style: Theme.of(context)
                                        .textTheme
                                        .displayLarge,
                                  ),
                                  TextSpan(
                                    text: " Days",
                                    style: Theme.of(context)
                                        .textTheme
                                        .displayMedium
                                        ?.copyWith(
                                            color: const Color(0xffA0A7AE)),
                                  ),
                                ],
                              ),
                            ),
                            CustomProgressBar(
                              progress: getProgress(),
                              lockPosition: 0,
                              addMileStoneLock: false,
                              color: AppColors.g40,
                              endValue: Text(
                                "${daysInCurrentMonth(currentPeriodProvider.monthStartDate)}",
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(
                                        color: getProgress() >= 1.0
                                            ? AppColors.n0
                                            : const Color(0xff9CA2BA)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 6.h),
                        child: const Divider(
                          color: AppColors.n30,
                        ),
                      ),
                      if (error == null)
                        // Main calendar view
                        Column(
                          children: [
                            // Days of the week
                            Row(
                              // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: daysOfWeek
                                  .map(
                                    (day) => Expanded(
                                      child: Text(
                                        day,
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelMedium
                                            ?.copyWith(
                                              color: AppColors.n70,
                                              fontStyle: FontStyle.italic,
                                            ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                            // Dates in the selected view
                            GridView.builder(
                              shrinkWrap: true,
                              itemCount:
                                  daysToDisplay.length + firstWeekdayOffset,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 7,
                                childAspectRatio: 0.9,
                              ),
                              padding: EdgeInsets.zero,
                              itemBuilder: (context, index) {
                                if (index < firstWeekdayOffset) {
                                  return const SizedBox.shrink();
                                }

                                final day =
                                    daysToDisplay[index - firstWeekdayOffset];
                                // final color = day.isAfter(DateTime.now())
                                //     ? AppColors.n30
                                //     : getDateColor(day);

                                return GestureDetector(
                                  onTap: () {
                                    // widget.onDateSelected(day);
                                  },
                                  child: Container(
                                    margin: EdgeInsets.symmetric(vertical: 9.r),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: getDateColor(day),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '${day.day}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            color: AppColors.n0,
                                            fontStyle: FontStyle.italic,
                                          ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 4.h),
                              child: const Divider(
                                color: AppColors.n30,
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      height: 16.r,
                                      width: 16.r,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppColors.g40,
                                      ),
                                    ),
                                    SizedBox(width: 8.w),
                                    Text(
                                      "Present",
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: AppColors.n80),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Container(
                                      height: 16.r,
                                      width: 16.r,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppColors.r40,
                                      ),
                                    ),
                                    SizedBox(width: 8.w),
                                    Text(
                                      "Absent",
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: AppColors.n80),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Container(
                                      height: 16.r,
                                      width: 16.r,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppColors.n90,
                                      ),
                                    ),
                                    SizedBox(width: 8.w),
                                    Text(
                                      "False Attendance/\nNo show",
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: AppColors.n80),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        )
                      else
                        Center(
                          child: Text(error ?? "Something went wrong"),
                        )
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
