import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/pages/payout/daily_earnings_breakdown.dart';
import 'package:snabbit_runner/pages/payout/fp1_view.dart';
import 'package:snabbit_runner/pages/payout/fp_warning.dart';
import 'package:snabbit_runner/pages/payout/payout_v2_handoff.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/utils/app_strings.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/utils/rate_card_utils.dart';
import 'package:snabbit_runner/widgets/common_app_bar.dart';
import 'package:snabbit_runner/widgets/payout/current_period_view.dart';

import '../../providers/daily_earnings.dart';
import '../../services/http_service.dart';
import '../../widgets/payout/attendance_status_view.dart';
import 'daily_earnings_state.dart';
import 'fp2_view.dart';
import 'payout_absent_view.dart';

/// Route arguments for [DailyEarningsList]. Pass via
/// `Navigator.pushNamed(DailyEarningsList.routeName, arguments: DailyEarningsListArgs(...))`.
class DailyEarningsListArgs {
  const DailyEarningsListArgs({this.initialMonth, this.fromWebview = false});

  /// Month the screen should land on. Any day-of-month is accepted; only
  /// year+month are read. When `null`, defaults to the current period.
  final DateTime? initialMonth;

  /// `true` when the runner was pushed here by the v2 webview for a
  /// pre-optin month. Used to decide whether a right-arrow tap landing
  /// on an optin-or-later month should pop back to the webview instead
  /// of advancing natively.
  final bool fromWebview;
}

/// Main page for Daily Earnings List
class DailyEarningsList extends StatefulWidget {
  static const String routeName = "/daily-earnings-list";

  const DailyEarningsList({super.key});

  @override
  State<DailyEarningsList> createState() => _DailyEarningsListState();
}

class _DailyEarningsListState extends State<DailyEarningsList> {
  late DailyEarningsListProvider listProvider;
  late CurrentPeriodProvider periodProvider;
  late LanguageProvider languageProvider;
  late UserProfileProvider userProfileProvider;
  bool init = true;

  /// `true` when opened from the v2 webview for a pre-optin month.
  /// See [DailyEarningsListArgs.fromWebview].
  bool _fromWebview = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (init) {
      init = false;
      listProvider =
          Provider.of<DailyEarningsListProvider>(context, listen: true);
      periodProvider =
          Provider.of<CurrentPeriodProvider>(context, listen: false);
      languageProvider = Provider.of<LanguageProvider>(context, listen: false);
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: false);
      // Seed the period provider when the web sends the runner here for
      // a pre-optin month (see [DailyEarningsListArgs]). Only seeds when
      // args are present — native nav keeps the existing behavior.
      final routeArgs = ModalRoute.of(context)?.settings.arguments;
      if (routeArgs is DailyEarningsListArgs) {
        _fromWebview = routeArgs.fromWebview;
        if (routeArgs.initialMonth != null) {
          periodProvider.updateCurrentDate(routeArgs.initialMonth!,
              notify: false);
        }
      }
      Future(() {
        initProcess();
      });
    }
  }

  /// Right-arrow intercept for the monthly period picker. When a v2 runner
  /// with a known opt-in month steps forward into v2 territory (the opt-in
  /// month or later) — which the native v1 screen doesn't serve — hands off
  /// to the v2 webview: pops back if the runner came from the webview,
  /// otherwise launches the v2 daily payouts page. Fires for native
  /// navigation too (not just from-webview). Returns `true` when handled.
  bool _maybeHandoffOnNextMonth() {
    if (!userProfileProvider.isRateCardV2Effective) return false;
    final user = userProfileProvider.user;
    final current = periodProvider.monthStartDate;
    final target = DateTime(current.year, current.month + 1, 1);
    if (!isInRateCardV2Territory(target, user?.rateCardOptinMonth)) {
      return false;
    }
    if (!mounted) return false;
    handoffToV2DailyPayouts(context, fromWebview: _fromWebview);
    return true;
  }

  void initProcess() {
    listProvider.fetchMonthlyEarnings(periodProvider.monthStartDate, periodProvider.monthEndDate);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8), // Match background from design
      appBar: CommonAppBar(
        centerTitle: false,
        elevation: 10.r,
        title: Text("#${userProfileProvider.user?.id}",
          style: Theme.of(context).textTheme.labelLarge,
        ),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(vertical: 24.h),
        child: Column(
          children: [
            // Month selector
            CurrentPeriodView(
              viewType: PayoutPeriod.monthly,
              onNextTapOverride: _maybeHandoffOnNextMonth,
              onChanged: () {
                listProvider
                    .fetchMonthlyEarnings(periodProvider.monthStartDate, periodProvider.monthEndDate);
              },
            ),

            // Main content
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: listProvider.loading
                    ? const Center(child: CupertinoActivityIndicator())
                    : listProvider.error != null
                        ? _buildErrorSection()
                        : _buildContentSection(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorSection() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "${languageProvider.getMessage('error', 'Error')}: ${listProvider.error}",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.r50,
                ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: () {
              listProvider.fetchMonthlyEarnings(periodProvider.monthStartDate, periodProvider.monthEndDate);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
            ),
            child: Text(
              languageProvider.getMessage('retry', 'Retry'),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentSection() {
    if (listProvider.earningsList.isEmpty) {
      return Center(
        child: Text(
          languageProvider.getMessage(
              'no_earnings_for_this_month', 'No earnings for this month'),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.n60,
              ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      children: [
        // Total earnings card
        Container(
          width: double.infinity,
          margin: EdgeInsets.only(top: 16.h, bottom: 24.h),
          padding: EdgeInsets.symmetric(vertical: 16.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                languageProvider.getMessage(
                  'monthly_earning',
                  'Monthly Earning',
                ),
                style: Theme.of(context).textTheme.labelLarge,
              ),
              SizedBox(height: 8.h),
              Text(
                formatIndianCurrency(listProvider.totalEarnings),
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: AppColors.g40,
                      fontSize: 28.sp,
                    ),
              ),
            ],
          ),
        ),

        // List of earnings
        Expanded(
          child: ListView.builder(
            itemCount: listProvider.earningsList.length,
            padding: EdgeInsets.only(bottom: 24.h),
            itemBuilder: (context, index) {
              final item = listProvider.earningsList[index];
              return Padding(
                padding: EdgeInsets.only(bottom: 12.h),
                child: _buildAttendanceWidget(item),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceWidget(DailyEarningListItem item) {
    switch (item.status) {
      case AttendanceStatus.PRESENT:
        return PresentWidget(
          item: item,
          onTap: () => _navigateToDetails(item.date),
          languageProvider: languageProvider,
        );
      case AttendanceStatus.ABSENT:
      case AttendanceStatus.EMERGENCY_LOGOUT:
        return AbsentWidget(
          item: item,
          onTap: () => _navigateToDetails(item.date),
          languageProvider: languageProvider,
        );
      case AttendanceStatus.FALSE_ATTENDANCE:
        return FalseAttendanceWidget(
          item: item,
          onTap: () => _navigateToDetails(item.date),
          languageProvider: languageProvider,
        );
      case AttendanceStatus.FALSE_ATTENDANCE_WARNING:
        return FalseAttendanceWarningWidget(
          item: item,
          onTap: () => _navigateToDetails(item.date),
          languageProvider: languageProvider,
        );
      case AttendanceStatus.NO_SHOW:
        return NoShowWidget(
          item: item,
          onTap: () => _navigateToDetails(item.date),
          languageProvider: languageProvider,
        );
      case AttendanceStatus.NO_SHOW_WARNING:
        return NoShowWarningWidget(
          item: item,
          onTap: () => _navigateToDetails(item.date),
          languageProvider: languageProvider,
        );
      default:
        return const Text('Illegal State');
    }
  }

  void _navigateToDetails(DateTime date) {
    periodProvider.currentDate = date;
    Navigator.pushNamed(
      context,
      DailyEarningState.routeName,
      // Carry the webview origin through so the day screen's boundary
      // handoff pops back to the runner's webview instead of launching a
      // fresh one; also seed the day it should land on.
      arguments: DailyEarningStateArgs(
        initialDate: date,
        fromWebview: _fromWebview,
      ),
    );
  }
}
