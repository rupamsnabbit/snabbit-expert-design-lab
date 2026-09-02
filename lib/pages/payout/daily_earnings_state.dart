import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/pages/payout/no_show_warning.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/widgets/raise_dispute/raise_dispute_button.dart';

import '../../providers/daily_earnings.dart';
import '../../providers/daily_earnings_provider.dart';
import '../../providers/language_provider.dart';
import '../../utils/common_methods.dart';
import '../../utils/enums.dart';
import '../../utils/rate_card_utils.dart';
import '../../widgets/common_app_bar.dart';
import '../../widgets/payout/current_period_view.dart';
import 'daily_earnings_breakdown.dart';
import 'fp1_view.dart';
import 'fp2_view.dart';
import 'fp_warning.dart';
import 'payout_absent_view.dart';
import 'payout_v2_handoff.dart';

/// Route arguments for [DailyEarningState]. Pass via
/// `Navigator.pushNamed(DailyEarningState.routeName, arguments: DailyEarningStateArgs(...))`.
class DailyEarningStateArgs {
  const DailyEarningStateArgs({this.initialDate, this.fromWebview = false});

  /// The exact day the screen should land on. When `null`, defaults to
  /// the current period's selected date.
  final DateTime? initialDate;

  /// `true` when the runner was pushed here by the v2 webview for a
  /// pre-optin day. Used to decide whether a right-arrow tap landing on
  /// an optin-or-later day should pop back to the webview instead of
  /// advancing natively.
  final bool fromWebview;
}

class DailyEarningState extends StatefulWidget {
  static const String routeName = "/daily-earnings-state";

  const DailyEarningState({super.key});

  @override
  State<DailyEarningState> createState() => _DailyEarningStateState();
}

class _DailyEarningStateState extends State<DailyEarningState> {
  late CurrentPeriodProvider periodProvider;
  late LanguageProvider languageProvider;
  late UserProfileProvider userProfileProvider;
  late DailyEarningsListProvider earningsListProvider;
  late DailyEarningsProvider earningsProvider;
  bool init = true;
  DailyEarningListItem? dailyEarningListItem;

  /// `true` when opened from the v2 webview for a pre-optin day.
  /// See [DailyEarningStateArgs.fromWebview].
  bool _fromWebview = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (init) {
      init = false;
      periodProvider =
          Provider.of<CurrentPeriodProvider>(context, listen: true);
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: false);
      earningsListProvider =
          Provider.of<DailyEarningsListProvider>(context, listen: true);
      earningsProvider =
          Provider.of<DailyEarningsProvider>(context, listen: false);
      // Seed the period provider when the web sends the runner here for
      // a pre-optin day (see [DailyEarningStateArgs]). Only seeds when
      // args are present — native nav keeps the existing behavior.
      final routeArgs = ModalRoute.of(context)?.settings.arguments;
      if (routeArgs is DailyEarningStateArgs) {
        _fromWebview = routeArgs.fromWebview;
        if (routeArgs.initialDate != null) {
          periodProvider.updateCurrentDate(routeArgs.initialDate!,
              notify: false);
        }
      }
      Future(() {
        fetchCurrentDay();
      });
    }
  }

  /// Right-arrow intercept for the daily period picker. When a v2 runner
  /// with a known opt-in month steps forward into v2 territory (the opt-in
  /// month or later) — which the native v1 screen doesn't serve — hands off
  /// to the v2 webview: pops back if the runner came from the webview,
  /// otherwise launches the v2 day-level summary seeded to the target day.
  /// Fires for native navigation too (not just from-webview). Returns
  /// `true` when handled.
  bool _maybeHandoffOnNextDay() {
    if (!userProfileProvider.isRateCardV2Effective) return false;
    final user = userProfileProvider.user;
    // Mirror CurrentPeriodView._switchToNext's day resolution: the
    // adjacent day from the loaded list, or currentDate + 1 as fallback.
    final nextDay = getNextDate() ??
        periodProvider.currentDate.add(const Duration(days: 1));
    if (!isInRateCardV2Territory(nextDay, user?.rateCardOptinMonth)) {
      return false;
    }
    if (!mounted) return false;
    handoffToV2DayPayouts(context, fromWebview: _fromWebview, date: nextDay);
    return true;
  }

  List<DailyEarningListItem> get earningsList =>
      earningsListProvider.earningsList ?? [];

  Future<void> fetchCurrentDay() async {
    try {
      final selectedDate = periodProvider.currentDate;
      dailyEarningListItem = earningsListProvider.earningsList.firstWhere(
        (item) => isSameDay(item.date, selectedDate),
      );
    } catch (e) {
      try {
        await earningsListProvider.fetchMonthlyEarnings(
            periodProvider.monthStartDate, periodProvider.monthEndDate);
        final selectedDate = periodProvider.currentDate;
        dailyEarningListItem = earningsListProvider.earningsList.firstWhere(
          (item) => isSameDay(item.date, selectedDate),
        );
      } catch (e) {
        // NO DATA CASE
        // DO NOTHING
      }
    }
    setState(() {});
  }

  Widget getMainWidget() {
    switch (dailyEarningListItem?.status) {
      case AttendanceStatus.PRESENT:
        Future(() {
          Provider.of<DailyEarningsProvider>(context, listen: false)
              .fetchDailyEarnings(periodProvider.currentDate);
        });
        return const DailyEarningsBreakdown();
      case AttendanceStatus.ABSENT:
        return const PayoutAbsentView();
      case AttendanceStatus.FALSE_ATTENDANCE:
        return const FPView();
      case AttendanceStatus.FALSE_ATTENDANCE_WARNING:
        return const FPWarningView();
      case AttendanceStatus.NO_SHOW_WARNING:
        Future(() {
          Provider.of<DailyEarningsProvider>(context, listen: false)
              .fetchDailyEarnings(periodProvider.currentDate);
        });
        return Column(
          children: [
            const NoShowWarningView(),
            SizedBox(height: 16.h),
            const DailyEarningsBreakdown(),
          ],
        );
      case AttendanceStatus.NO_SHOW:
        Future(() {
          Provider.of<DailyEarningsProvider>(context, listen: false)
              .fetchDailyEarnings(periodProvider.currentDate);
        });
        return Column(
          children: [
            const NoShowView(),
            SizedBox(height: 16.h),
            const DailyEarningsBreakdown(),
          ],
        );
      case AttendanceStatus.EMERGENCY_LOGOUT:
        Future(() {
          Provider.of<DailyEarningsProvider>(context, listen: false)
              .fetchDailyEarnings(periodProvider.currentDate);
        });
        return Column(
          children: [
            const PayoutAbsentView(),
            SizedBox(height: 16.h),
            const DailyEarningsBreakdown(),
          ],
        );
      default:
        return const Text('Payout data is not available');
    }
  }

  DateTime? getNextDate() {
    int match = earningsListProvider.earningsList.indexWhere(
      (element) => element.date.isAtSameMomentAs(periodProvider.currentDate),
    );
    if (match != -1) {
      final newIndex = match - 1;
      if (newIndex > 0) {
        return earningsList[newIndex].date;
      }
    }
    return null;
  }

  DateTime? getPreviousDate() {
    int match = earningsListProvider.earningsList.indexWhere(
      (element) => element.date.isAtSameMomentAs(periodProvider.currentDate),
    );
    if (match != -1) {
      final newIndex = match + 1;
      if (newIndex < earningsList.length - 1) {
        return earningsList[newIndex].date;
      }
    }
    return null;
  }

  bool get isNextDisabled {
    try {
      final val = periodProvider.currentDate
          .isAtSameMomentAs(earningsList.first.date);
      return val;
    } catch (_) {
      return false;
    }
  }

  bool get isPreviousDisabled {
    try {
      final val = periodProvider.currentDate
          .isAtSameMomentAs(earningsList.last.date);
      return val;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: CommonAppBar(
        title: Text(
          "#${userProfileProvider.user?.id}",
          style: Theme.of(context).textTheme.labelLarge,
        ),
        actions: const [
          ReportIssueButton(),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(height: 24.h),
              // Using CurrentPeriodView with the correct implementation
              CurrentPeriodView(
                viewType: PayoutPeriod.daily,
                nextDate: getNextDate(),
                previousDate: getPreviousDate(),
                onNextTapOverride: _maybeHandoffOnNextDay,
                onChanged: () async {
                  await fetchCurrentDay();
                  setState(() {});
                },
                isNextDisabled: isNextDisabled,
                isPreviousDisabled: isPreviousDisabled,
              ),
              SizedBox(height: 24.h),
              earningsListProvider.loading
                  ? const Center(child: CupertinoActivityIndicator())
                  : getMainWidget(),
            ],
          ),
        ),
      ),
    );
  }
}
