import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/widgets/payout/current_period_view.dart';
import 'package:snabbit_runner/widgets/payout/custom_progress_bar.dart';
import 'package:snabbit_runner/widgets/payout/payout_section_container.dart';

import '../../providers/payout.dart';
import '../../services/payout_http.dart';
import '../../utils/colors.dart';
import '../../utils/constants.dart';
import '../../widgets/drawer/drawer_menu.dart';

class IncentiveDetails extends StatefulWidget {
  static const String routeName = "/incentive-details";

  const IncentiveDetails({super.key});

  @override
  State<IncentiveDetails> createState() => _IncentiveDetailsState();
}

class _IncentiveDetailsState extends State<IncentiveDetails> {
  bool init = true;
  bool loading = true;
  String? error;
  late PayoutProvider payoutProvider;
  late CurrentPeriodProvider currentPeriodProvider;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      payoutProvider = Provider.of<PayoutProvider>(context, listen: true);
      currentPeriodProvider =
          Provider.of<CurrentPeriodProvider>(context, listen: true);
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
    try {
      Response? response = await PayoutHttp.getIncentives(
          start: currentPeriodProvider.monthStartDate,
          end: currentPeriodProvider.monthEndDate);
      if (response != null) {
        error = null;
        payoutProvider.setIncentives(response.data);
      } else {
        error = "Something went wrong";
      }
    } catch (e) {
      error = "Something went wrong - $e";
    }
  }

  bool isAttendanceTargetAchieved() {
    try {
      return payoutProvider.incentives?.attendanceIncentives?.daysPresent !=
              null &&
          payoutProvider.incentives?.attendanceIncentives?.rewardTarget !=
              null &&
          payoutProvider.incentives!.attendanceIncentives!.daysPresent! >=
              payoutProvider.incentives!.attendanceIncentives!.rewardTarget!;
    } catch (e) {
      return false;
    }
  }

  double attendanceLockPosition() {
    try {
      return 1 -
          (payoutProvider.incentives!.attendanceIncentives!.rewardTarget! /
              daysInCurrentMonth(currentPeriodProvider.monthStartDate));
    } catch (e) {
      return 0.0;
    }
  }

  double attendanceProgress() {
    try {
      return payoutProvider.incentives!.attendanceIncentives!.daysPresent! /
          daysInCurrentMonth(currentPeriodProvider.monthStartDate);
    } catch (e) {
      return 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const DrawerMenu(),
      backgroundColor: const Color(0xffF5F6F8),
      appBar: AppBar(
        leading: Builder(
          builder: (BuildContext ctx) {
            return IconButton(
              onPressed: () async {
                Scaffold.of(ctx).openDrawer();
              },
              icon: const Icon(
                Icons.menu,
                color: AppColors.n90,
              ),
            );
          },
        ),
        elevation: 10.r,
        centerTitle: true,
        title: Text(
          "Incentives",
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
      body: loading
          ? const Center(
              child: CupertinoActivityIndicator(),
            )
          : Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 16.w,
                vertical: 20.h,
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    PayoutSectionContainer(
                      child: Column(
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.h),
                            child: CurrentPeriodView(
                              viewType: PayoutPeriod.monthly,
                              onChanged: () async {
                                setState(() {
                                  loading = true;
                                });
                                await initProcess();
                                setState(() {
                                  loading = false;
                                });
                              },
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 4.h),
                            child: const Divider(
                              color: AppColors.n30,
                            ),
                          ),
                          Container(
                            width: 1.sw,
                            padding: EdgeInsets.symmetric(vertical: 7.h),
                            decoration: BoxDecoration(
                              color: AppColors.g40,
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  payoutProvider
                                          .incentives?.totalIncentives?.title ??
                                      "Bonus ki kamai",
                                  style: Theme.of(context)
                                      .textTheme
                                      .displaySmall
                                      ?.copyWith(color: AppColors.n0),
                                ),
                                SizedBox(height: 8.h),
                                Text(
                                  "₹${anyValueToInt(payoutProvider.incentives?.totalIncentives?.value)}",
                                  style: Theme.of(context)
                                      .textTheme
                                      .displayLarge
                                      ?.copyWith(color: AppColors.n0),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 4.h),
                        ],
                      ),
                    ),
                    if (error == null)
                      Column(
                        children: [
                          Padding(
                            padding: EdgeInsets.only(top: 8.h),
                            child: PayoutSectionContainer(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Attendance",
                                    style: Theme.of(context)
                                        .textTheme
                                        .displayMedium,
                                  ),
                                  Text(
                                    "Number of days you were present",
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                            color: const Color(0xff959799)),
                                  ),
                                  SizedBox(height: 16.h),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Attendance Bonus",
                                            style: Theme.of(context)
                                                .textTheme
                                                .displaySmall,
                                          ),
                                          SizedBox(height: 8.h),
                                          RichText(
                                            text: TextSpan(
                                              children: [
                                                TextSpan(
                                                  text:
                                                      "${payoutProvider.incentives?.attendanceIncentives?.daysPresent}/${payoutProvider.incentives?.attendanceIncentives?.rewardTarget}",
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
                                                          color: const Color(
                                                              0xffA0A7AE)),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (isAttendanceTargetAchieved())
                                        Text(
                                          "Reward: ₹${anyValueToInt(payoutProvider.incentives?.attendanceIncentives?.reward)}",
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  color:
                                                      const Color(0xffA0A7AE)),
                                        ),
                                    ],
                                  ),
                                  SizedBox(height: 4.h),
                                  CustomProgressBar(
                                    progress: attendanceProgress(),
                                    lockPosition: attendanceLockPosition(),
                                    endValue: Text(
                                      "${daysInCurrentMonth(currentPeriodProvider.monthStartDate)}",
                                      style: Theme.of(context)
                                          .textTheme
                                          .displaySmall
                                          ?.copyWith(
                                            color: attendanceProgress() >= 1
                                                ? AppColors.n0
                                                : null,
                                          ),
                                    ),
                                  ),
                                  if (isAttendanceTargetAchieved() == false)
                                    Padding(
                                      padding: EdgeInsets.only(top: 16.h),
                                      child: Container(
                                        width: 1.sw,
                                        decoration: BoxDecoration(
                                          color: AppColors.g10,
                                          borderRadius:
                                              BorderRadius.circular(4.r),
                                        ),
                                        padding: EdgeInsets.symmetric(
                                          vertical: 7.h,
                                          horizontal: 12.w,
                                        ),
                                        child: RichText(
                                          textAlign: TextAlign.center,
                                          text: TextSpan(
                                            children: [
                                              TextSpan(
                                                text:
                                                    "Attend ${payoutProvider.incentives?.attendanceIncentives?.rewardTarget} days of work to unlock bonus of ",
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleLarge
                                                    ?.copyWith(
                                                      fontSize: 11.sp,
                                                      color: AppColors.g50,
                                                    ),
                                              ),
                                              TextSpan(
                                                text:
                                                    "₹${payoutProvider.incentives?.attendanceIncentives?.maxReward}",
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleLarge
                                                    ?.copyWith(
                                                      fontSize: 11.sp,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: AppColors.g50,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          RatingsIncentivesView(
                            payoutProvider: payoutProvider,
                          ),
                          SizedBox(
                            width: 1.sw,
                            child: Padding(
                              padding: EdgeInsets.only(top: 8.h),
                              child: PayoutSectionContainer(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Weekend",
                                      style: Theme.of(context)
                                          .textTheme
                                          .displayMedium,
                                    ),
                                    SizedBox(height: 16.h),
                                    Text(
                                      "Special Bonus",
                                      style: Theme.of(context)
                                          .textTheme
                                          .displaySmall,
                                    ),
                                    SizedBox(height: 8.h),
                                    Text(
                                      "₹${payoutProvider.incentives?.specialIncentives?.reward ?? 0}",
                                      style: Theme.of(context)
                                          .textTheme
                                          .displayLarge
                                          ?.copyWith(color: AppColors.g40),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (payoutProvider.incentives?.otherIncentives?.isNotEmpty ?? false)
                            Column(
                              children:
                                  payoutProvider.incentives!.otherIncentives!
                                      .map(
                                        (e) => SizedBox(
                                          width: 1.sw,
                                          child: Padding(
                                            padding: EdgeInsets.only(top: 8.h),
                                            child: PayoutSectionContainer(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Padding(
                                                    padding: EdgeInsets.only(bottom: 16.h),
                                                    child: Text(e?.title ?? "",
                                                      style: Theme.of(context).textTheme.displayMedium,
                                                    ),
                                                  ),
                                                  Padding(padding: EdgeInsets.only(bottom: 8.h,),
                                                    child: Text(e?.subtitle ?? "",
                                                      style: Theme.of(context).textTheme.displaySmall,
                                                    ),
                                                  ),
                                                  Text(
                                                    "₹${e?.reward ?? 0}",
                                                    style: Theme.of(context).textTheme.displayLarge?.copyWith(color: AppColors.g40),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                            ),
                        ],
                      )
                    else
                      Text("$error"),
                  ],
                ),
              ),
            ),
    );
  }
}

class RatingsIncentivesView extends StatelessWidget {
  final PayoutProvider payoutProvider;

  const RatingsIncentivesView({
    super.key,
    required this.payoutProvider,
  });

  bool isRatingsTargetAchieved() {
    try {
      return payoutProvider.incentives?.ratingsIncentives?.avgRating != null &&
          payoutProvider.incentives?.ratingsIncentives?.rewardTarget != null &&
          payoutProvider.incentives!.ratingsIncentives!.avgRating! >=
              payoutProvider.incentives!.ratingsIncentives!.rewardTarget!;
    } catch (e) {
      return false;
    }
  }

  double ratingLockPosition() {
    try {
      return 1 -
          (payoutProvider.incentives!.ratingsIncentives!.rewardTarget! /
              highestRating);
    } catch (e) {
      return 0.0;
    }
  }

  double ratingProgress() {
    try {
      return payoutProvider.incentives!.ratingsIncentives!.avgRating! /
          highestRating;
    } catch (e) {
      return 0.0;
    }
  }

  bool isRatingsIncentivesEnabled() {
    try {
      return payoutProvider.incentives!.attendanceIncentives!.daysPresent! >=
          payoutProvider.incentives!.ratingsIncentives!.minAttendanceTarget!;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 8.h),
      child: PayoutSectionContainer(
        child: Column(
          children: [
            if (isRatingsIncentivesEnabled() == false)
              Padding(
                padding: EdgeInsets.only(bottom: 16.h),
                child: Container(
                  width: 1.sw,
                  decoration: BoxDecoration(
                    color: AppColors.r10,
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  padding: EdgeInsets.symmetric(
                    vertical: 7.h,
                    horizontal: 12.w,
                  ),
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text:
                              "Attend ${payoutProvider.incentives?.ratingsIncentives?.minAttendanceTarget} days of work to unlock bonus of ",
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontSize: 11.sp,
                                    color: AppColors.r50,
                                  ),
                        ),
                        TextSpan(
                          text:
                              "₹${payoutProvider.incentives?.ratingsIncentives?.maxReward}",
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.r50,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Opacity(
              opacity: isRatingsIncentivesEnabled() == false ? 0.3 : 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Ratings",
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  Text(
                    "The ratings given to you this month",
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: const Color(0xff959799)),
                  ),
                  SizedBox(height: 16.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Monthly Incentive",
                            style: Theme.of(context).textTheme.displaySmall,
                          ),
                          SizedBox(height: 8.h),
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text:
                                      "${payoutProvider.incentives?.ratingsIncentives?.avgRating}/${payoutProvider.incentives?.ratingsIncentives?.rewardTarget}",
                                  style:
                                      Theme.of(context).textTheme.displayLarge,
                                ),
                                const WidgetSpan(
                                  child: Icon(
                                    Icons.star_rounded,
                                    color: Color(0xff40515B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (isRatingsTargetAchieved())
                        Text(
                          "Reward: ₹${payoutProvider.incentives?.ratingsIncentives?.reward}",
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xffA0A7AE),
                                  ),
                        ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  CustomProgressBar(
                    progress: ratingProgress(),
                    lockPosition: ratingLockPosition(),
                    endValue: Text(
                      "$highestRating",
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: ratingProgress() >= 1 ? AppColors.n0 : null),
                    ),
                  ),
                  if (isRatingsTargetAchieved() == false &&
                      isRatingsIncentivesEnabled() == true)
                    Padding(
                      padding: EdgeInsets.only(top: 16.h),
                      child: Container(
                        width: 1.sw,
                        decoration: BoxDecoration(
                          color: AppColors.g10,
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        padding: EdgeInsets.symmetric(
                          vertical: 7.h,
                          horizontal: 12.w,
                        ),
                        child: RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text:
                                    "Achieve rating above ${payoutProvider.incentives?.ratingsIncentives?.rewardTarget} to unlock bonus of ",
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      fontSize: 11.sp,
                                      color: AppColors.g50,
                                    ),
                              ),
                              TextSpan(
                                text:
                                    "₹${payoutProvider.incentives?.ratingsIncentives?.maxReward}",
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.g50,
                                    ),
                              ),
                            ],
                          ),
                        ),
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
