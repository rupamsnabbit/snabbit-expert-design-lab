import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/daily_earnings_provider.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/widgets/payout/daily_earning_section.dart';
import 'package:snabbit_runner/widgets/payout/job_entry_card.dart';
import 'package:snabbit_runner/widgets/payout/current_period_view.dart';
import 'package:snabbit_runner/widgets/payout/shift_performance_breakdown_card.dart';

import '../../providers/language_provider.dart';

class DailyEarningsBreakdown extends StatefulWidget {
  const DailyEarningsBreakdown({super.key});

  @override
  State<DailyEarningsBreakdown> createState() => _DailyEarningsBreakdownState();
}

class _DailyEarningsBreakdownState extends State<DailyEarningsBreakdown> {
  late DailyEarningsProvider earningsProvider;
  late CurrentPeriodProvider periodProvider;
  late LanguageProvider languageProvider;
  bool init = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (init) {
      init = false;
      earningsProvider =
          Provider.of<DailyEarningsProvider>(context, listen: true);
      periodProvider =
          Provider.of<CurrentPeriodProvider>(context, listen: true);
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      earningsProvider.loading = true;
      Future(() {
        initProcess();
      });
    }
  }

  Future<void> initProcess() async {
    await fetchDailyEarnings();
  }

  Future<void> fetchDailyEarnings() async {
    // Get the current date from the periodProvider
    DateTime selectedDate = periodProvider.currentDate;
    await earningsProvider.fetchDailyEarnings(selectedDate);
  }

  @override
  Widget build(BuildContext context) {
    return earningsProvider.loading
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CupertinoActivityIndicator(),
                SizedBox(height: 16.h),
                Text(
                  languageProvider.getMessage('loading', 'Loading...'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.n60,
                      ),
                ),
              ],
            ),
          )
        : _buildMainContent();
  }

  Widget _buildMainContent() {
    if (earningsProvider.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "${languageProvider.getMessage('error', 'Error')}: ${earningsProvider.error}",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.r50,
                  ),
            ),
            SizedBox(height: 16.h),
            ElevatedButton(
              onPressed: initProcess,
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

    if (earningsProvider.dailyEarningsData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 48.r, color: AppColors.n60),
            SizedBox(height: 16.h),
            Text(
              languageProvider.getMessage(
                  'no_data_available', 'No data available for this date'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.n60,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (earningsProvider.dailyEarningsData?.shiftPerformanceDetails != null)
          ShiftPerformanceBreakdownCard(
            shiftPerformanceDetails:
                earningsProvider.dailyEarningsData!.shiftPerformanceDetails!,
          ),

        // Daily Earnings section
        DailyEarningSection(
          data: earningsProvider.dailyEarningsData?.dailyEarnings,
          earnStatusText: earningsProvider
              .dailyEarningsData!.shiftPerformanceDetails?.subTitle,
        ),

        // Job Tracker section
        if (earningsProvider.dailyEarningsData?.jobDetails?.isNotEmpty ??
            false) ...[
          Padding(
            padding: EdgeInsets.only(top: 8.h, bottom: 16.h),
            child: Text(
              languageProvider.getMessage('job_tracker', 'Job Tracker'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF40515B),
                  ),
            ),
          ),
          if (earningsProvider.dailyEarningsData?.loginLocation != null)...[
            SizedBox(height: 8.h),
            Row(
              children: [
                Expanded(
                  child: Divider(
                    color: AppColors.n30,
                    thickness: 1.r,
                  ),
                ),
                SizedBox(width: 12.w),
                Text(
                  languageProvider.getFormattedMessage(
                    earningsProvider.dailyEarningsData!.loginLocation!.key ??
                        'login_location',
                    earningsProvider.dailyEarningsData!.loginLocation!.text ??
                        '{{location}}',
                    earningsProvider.dailyEarningsData!.loginLocation!.data !=
                            null
                        ? {
                            'location': earningsProvider
                                    .dailyEarningsData!
                                    .loginLocation!
                                    .data!
                                    .location ??
                                ''
                          }
                        : {},
                  ),
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: AppColors.n60,
                      ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Divider(
                    color: AppColors.n30,
                    thickness: 1.r,
                  ),
                ),
              ],
            ),
            SizedBox(height: 24.h),
          ],
          ...(earningsProvider.dailyEarningsData?.jobDetails ?? [])
              .map((job) => JobEntryCard(
                    job: job,
                    minsWorked: job.duration,
                  )),
        ],
        // Add bottom padding for scrolling
        SizedBox(height: 24.h),
      ],
    );
  }
}
