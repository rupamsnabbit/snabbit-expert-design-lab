import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/payout.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/payout_http.dart';
import 'package:snabbit_runner/utils/app_strings.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/utils/rate_card_utils.dart';
import 'package:snabbit_runner/widgets/common_app_bar.dart';
import 'package:snabbit_runner/widgets/drawer/drawer_menu.dart';
import 'package:snabbit_runner/widgets/payout/attendance_bonus_popup.dart';
import 'package:snabbit_runner/widgets/payout/current_period_view.dart';
import 'package:snabbit_runner/widgets/payout/earning_item_card.dart';
import 'package:snabbit_runner/widgets/payout/joining_bonus_popup.dart';
import 'package:snabbit_runner/widgets/payout/payout_section_container.dart';
import 'package:snabbit_runner/widgets/payout/rating_bonus_popup.dart';

import '../../payout/widgets/super_bonus_popup.dart' show showSuperBonusDialog;

class BonusHome extends StatefulWidget {
  static const String routeName = "/bonus-home";

  const BonusHome({super.key});

  @override
  State<BonusHome> createState() => _BonusHomeState();
}

class _BonusHomeState extends State<BonusHome> {
  bool init = true;
  bool loading = true;
  String? error;
  late UserProfileProvider userProfileProvider;
  late CurrentPeriodProvider currentPeriodProvider;
  late PayoutProvider payoutProvider;
  late LanguageProvider languageProvider;
  DeductionData? _ratingDeduction;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
      payoutProvider = Provider.of<PayoutProvider>(context, listen: true);
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      currentPeriodProvider =
          Provider.of<CurrentPeriodProvider>(context, listen: true);

      initProcess().then((_) {
        loading = false;
        if (mounted) {
          setState(() {});
        }
      }).onError((e, __) {
        error = e.toString();
        setState(() {});
      });
    }
    super.didChangeDependencies();
  }

  Future<void> initProcess() async {
    await fetchIncentives();
    await fetchDeductions();
  }

  Future<void> fetchIncentives() async {
    try {
      Response? response = await PayoutHttp.getIncentives(
          start: currentPeriodProvider.monthStartDate,
          end: currentPeriodProvider.monthEndDate);

      if (response != null) {
        error = null;
        payoutProvider.setIncentives(response.data);
      } else {
        payoutProvider.setIncentives(null);
        error = "Something went wrong";
      }
    } catch (e) {
      error = "Something went wrong - $e";
      payoutProvider.setIncentives(null);
    }
  }

  void resetDeductionEntry() {
    payoutProvider.setDeductionDetails(null);
    _ratingDeduction = null;
  }

  Future<void> fetchDeductions() async {
    try {
      resetDeductionEntry();
      Response? response = await PayoutHttp.getDeductionDetails(
          start: currentPeriodProvider.monthStartDate,
          end: currentPeriodProvider.monthEndDate);
      if (response != null) {
        error = null;
        payoutProvider.setDeductionDetails(response.data);
        int index = payoutProvider.deductionDetails?.deductions?.items
                ?.indexWhere(
                    (element) => element.name == AppStrings.ratingDeduction) ??
            -1;
        if (index != -1) {
          _ratingDeduction =
              payoutProvider.deductionDetails?.deductions?.items?[index];
        }
      } else {
        resetDeductionEntry();
        error = "Something went wrong";
      }
    } catch (e) {
      resetDeductionEntry();
      error = "Something went wrong - $e";
    }
  }

  //post payout and has rating violations
  bool get hasRatingViolations =>
      payoutProvider.incentives?.ratingsIncentives?.isAchieved == true &&
      (absentWeekDays.isNotEmpty || attendanceViolation || _ratingScoreIsStale);

  bool get _ratingScoreIsStale =>
      ((payoutProvider.incentives?.ratingsIncentives?.avgRating ?? 0) >
          (_ratingDeduction?.deductionTarget ?? 0)) &&
      ((payoutProvider.incentives?.ratingsIncentives?.avgRating ?? 0) <
          (payoutProvider.incentives?.ratingsIncentives?.rewardTarget ?? 0));

  bool get attendanceViolation =>
      (payoutProvider.incentives?.attendanceIncentives?.absentDays ?? 0) >
      (payoutProvider.incentives?.attendanceIncentives?.maxAbsentDays ?? 0);

  List<String> get absentWeekDays {
    return payoutProvider.incentives?.ratingsIncentives?.absentWeekDays ?? [];
  }

  /// Check if runner has attended enough days to show performance bonus
  /// Minimum requirement: n-4 days where n is total days in month
  bool get _hasMinimumAttendanceForBonus {
    try {
      // Calculate total days in current month using standard utility
      final totalDaysInMonth =
          daysInCurrentMonth(currentPeriodProvider.monthStartDate);

      // Minimum required attendance: total days - 4
      final minRequiredAttendance = totalDaysInMonth - 4;

      // Get absent days from attendance incentives
      final absentDays =
          payoutProvider.incentives?.attendanceIncentives?.absentDays ?? 0;

      // Calculate actual attendance days
      final actualAttendanceDays = totalDaysInMonth - absentDays;

      // Show bonus only if runner has attended at least n-4 days
      return actualAttendanceDays >= minRequiredAttendance;
    } catch (e) {
      // If calculation fails, default to showing the bonus
      return true;
    }
  }

  /// Chevron-right intercept. For a v2 runner with a known opt-in month,
  /// blocks stepping forward from a pre-opt-in (v1) month into opt-in-or-
  /// later (v2) territory — the native v1 Bonus screen doesn't serve those
  /// months (the new Payouts does). Shows a toast and returns `true`
  /// (handled) so the period view skips its default advance. Returns
  /// `false` otherwise, letting normal month navigation proceed.
  bool _maybeBlockNextMonth() {
    if (payoutProvider.payoutPeriod != PayoutPeriod.monthly) return false;
    if (!userProfileProvider.isRateCardV2Effective) return false;
    final user = userProfileProvider.user;
    final current = currentPeriodProvider.monthStartDate;
    final nextMonth = DateTime(current.year, current.month + 1, 1);
    if (!isInRateCardV2Territory(nextMonth, user?.rateCardOptinMonth)) {
      return false;
    }
    if (!mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          languageProvider.getMessage(
            'bonus_v2_month_unavailable',
            "Bonus for this month is in the new Payouts",
          ),
        ),
      ),
    );
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const DrawerMenu(),
      backgroundColor: const Color(0xffF5F6F8),
      appBar: CommonAppBar(
        elevation: 10.r,
        centerTitle: true,
        title: Text(
          languageProvider.getMessage("bonus_earnings", "Bonus earnings"),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        child: loading
            ? const Center(
                child: CupertinoActivityIndicator(),
              )
            : SingleChildScrollView(
                child: Column(
                  children: [
                    // Month selector
                    Padding(
                      padding: EdgeInsets.only(top: 17.h, bottom: 24.h),
                      child: CurrentPeriodView(
                        viewType: payoutProvider.payoutPeriod,
                        onNextTapOverride: _maybeBlockNextMonth,
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
                    // Main content
                    PayoutSectionContainer(
                      child: Column(
                        children: [
                          // Bonus amount
                          SizedBox(height: 16.h),
                          Text(
                            languageProvider.getMessage(
                                "bonus_earnings", "Bonus earnings"),
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontSize: 16.sp,
                                ),
                          ),
                          Text(
                            formatIndianCurrency(getAmount()),
                            style: Theme.of(context)
                                .textTheme
                                .displayLarge
                                ?.copyWith(
                                  fontSize: 28.5.sp,
                                  color: getAmount() < 0
                                      ? AppColors.r40
                                      : AppColors.g40,
                                  fontStyle: FontStyle.normal,
                                ),
                          ),
                          SizedBox(height: 16.h),
                          const Divider(
                            color: AppColors.n30,
                          ),
                          SizedBox(height: 8.h),

                          // Super Bonus Card
                          if (payoutProvider.incentives?.superBonus != null)
                            EarningItemCard(
                              title: languageProvider.getMessage(
                                  "super_bonus", "Super Bonus"),
                              amount: payoutProvider
                                      .incentives?.superBonus?.amount ??
                                  0,
                              textColor: _getTextColor(payoutProvider
                                  .incentives?.superBonus?.paymentState),
                              borderColor: AppColors.n40,
                              paymentState: payoutProvider
                                  .incentives?.superBonus?.paymentState,
                              onTap: () {
                                showSuperBonusDialog(context);
                              },
                            ),

                          // Attendance Bonus Card
                          if (payoutProvider.incentives?.attendanceIncentives !=
                              null)
                            EarningItemCard(
                              title: languageProvider.getMessage(
                                  "attendance_bonus", "Attendance Bonus"),
                              amount: payoutProvider.incentives
                                      ?.attendanceIncentives?.maxReward ??
                                  0,
                              textColor: _getTextColor(payoutProvider.incentives
                                  ?.attendanceIncentives?.paymentState),
                              borderColor: AppColors.n40,
                              paymentState: payoutProvider.incentives
                                  ?.attendanceIncentives?.paymentState,
                              subtitle:_buildAbsentDaysIndicator(
                                payoutProvider.incentives?.attendanceIncentives
                                        ?.absentDays ??
                                    0,
                                payoutProvider.incentives?.attendanceIncentives
                                        ?.maxAbsentDays ??
                                    0,
                              ),
                              onTap: () {
                                showAttendanceBonusDialog(context);
                              },
                            ),

                          // Performance Bonus Card
                          if (_hasMinimumAttendanceForBonus &&
                              _ratingDeduction?.status !=
                                  DeductionState.success &&
                              payoutProvider.incentives?.ratingsIncentives !=
                                  null &&
                              payoutProvider.incentives?.ratingsIncentives
                                      ?.paymentState !=
                                  PaymentState.deducted)
                            EarningItemCard(
                              title: languageProvider.getMessage(
                                  "performance_bonus", "Performance Bonus"),
                              amount: payoutProvider.incentives
                                      ?.ratingsIncentives?.maxReward ??
                                  0,
                              textColor: hasRatingViolations
                                  ? const Color(0xFF40515B)
                                  : _getTextColor(payoutProvider.incentives
                                      ?.ratingsIncentives?.paymentState),
                              borderColor: AppColors.n40,
                              paymentState: payoutProvider
                                  .incentives?.ratingsIncentives?.paymentState,
                              onTap: () {
                                showRatingBonusDialog(context);
                              },
                            )
                          else if (_ratingDeduction?.status ==
                              DeductionState.success)
                            EarningItemCard(
                              title: languageProvider.getMessage(
                                  "performance_penalty", "Performance Penalty"),
                              amount: _ratingDeduction?.amount ?? 0,
                              textColor: _getTextColor(PaymentState.deducted),
                              borderColor: AppColors.n40,
                              paymentState: PaymentState.deducted,
                              onTap: () {
                                showRatingBonusDialog(context);
                              },
                            ),
                          // Joining Bonus Card
                          if (payoutProvider.incentives?.joiningBonus != null)
                            EarningItemCard(
                              title: languageProvider.getMessage(
                                  "joining_bonus", "Joining Bonus"),
                              amount:
                                  payoutProvider.incentives?.joiningBonus?.jb ??
                                      0,
                              textColor: _getTextColor(payoutProvider
                                  .incentives?.joiningBonus?.paymentState),
                              borderColor: AppColors.n40,
                              paymentState: payoutProvider
                                  .incentives?.joiningBonus?.paymentState,
                              onTap: () {
                                showJoiningBonusDialog(context);
                              },
                            ),

                          // Festive Bonus Card
                          // EarningItemCard(
                          //   title: languageProvider.getMessage(
                          //       "festive_bonus", "Festive Bonus"),
                          //   amount: payoutProvider
                          //           .incentives?.specialIncentives?.reward ??
                          //       0,
                          //   textColor: _getTextColor(payoutProvider
                          //       .incentives?.specialIncentives?.paymentState),
                          //   borderColor: AppColors.n40,
                          //   paymentState: payoutProvider
                          //       .incentives?.specialIncentives?.paymentState,
                          //   onTap: () {
                          //     // Navigate to festive bonus details
                          //   },
                          // ),

                          SizedBox(height: 8.h),
                        ],
                      ),
                    ),
                    SizedBox(height: 24.h),
                  ],
                ),
              ),
      ),
    );
  }

  Color _getTextColor(PaymentState? paymentState) =>
      paymentState == PaymentState.missed ||
              paymentState == PaymentState.deducted
          ? AppColors.r60
          : AppColors.g50;

  // Helper method to build absent days indicator
  Widget? _buildAbsentDaysIndicator(int absentDays, int allowedDays) {
    if (absentDays == 0) return null;

    final bool isExceeded = absentDays > allowedDays;

    return Container(
      margin: EdgeInsets.only(top: 3.h),
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: isExceeded ? AppColors.r40 : AppColors.y20,
        borderRadius: BorderRadius.circular(4.095.r),
      ),
      child: Text(
        "${languageProvider.getMessage("days_absent", "Days absent")}: $absentDays/$allowedDays",
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: isExceeded ? AppColors.n0 : AppColors.y60,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  int getAmount() {
    final deduction = _ratingDeduction?.status == DeductionState.success
        ? _ratingDeduction?.amount
        : null;
    return (anyValueToInt(payoutProvider.incentives?.totalIncentives?.value) ??
            0) -
        (deduction ?? 0);
  }
}
