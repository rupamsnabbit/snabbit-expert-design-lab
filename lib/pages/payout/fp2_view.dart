import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/app_strings.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/widgets/common_app_bar.dart';
import 'package:snabbit_runner/widgets/payout/current_period_view.dart';
import 'package:snabbit_runner/utils/common_methods.dart';

import '../../providers/daily_earnings.dart';
import 'daily_earnings_list.dart';

class NoShowView extends StatefulWidget {
  const NoShowView({super.key});

  @override
  State<NoShowView> createState() => _NoShowViewState();
}

class _NoShowViewState extends State<NoShowView> {
  bool init = true;
  late LanguageProvider languageProvider;
  late CurrentPeriodProvider currentPeriodProvider;
  late DailyEarningsListProvider earningsListProvider;
  int? _amount;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      currentPeriodProvider =
          Provider.of<CurrentPeriodProvider>(context, listen: true);
      earningsListProvider =
          Provider.of<DailyEarningsListProvider>(context, listen: true);

      // Get the amount for the selected date
      _fetchAmountForSelectedDate();
    }
  }

  void _fetchAmountForSelectedDate() {
    try {
      final selectedDate = currentPeriodProvider.currentDate;
      final selectedItem = earningsListProvider.earningsList.firstWhere(
        (item) => isSameDay(item.date, selectedDate),
      );

      _amount = selectedItem.amount;
    } catch (e) {
      _amount = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // False Attendance panel
    if (_amount != null) {
      return FalseAttendancePanel(
        date: currentPeriodProvider.currentDate,
        languageProvider: languageProvider,
        amount: _amount!,
      );
    } else {
      return const Text('No data found');
    }
  }
}

class FalseAttendancePanel extends StatelessWidget {
  final DateTime date;
  final LanguageProvider languageProvider;
  final int amount;

  const FalseAttendancePanel({
    super.key,
    required this.date,
    required this.languageProvider,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: AppColors.n0,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: const Color(0xffF3F4F6)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Amount display
          Container(
            width: 100.w,
            height: 55.h,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4.r),
              border: Border.all(
                color: AppColors.r40,
                width: 4.r,
              ),
            ),
            child: Text(
              formatIndianCurrency(amount),
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: AppColors.n90,
                    fontSize: 21.sp,
                  ),
            ),
          ),
          SizedBox(height: 32.h),

          // FALSE ATTENDANCE text
          Text(
            languageProvider.getMessage('false_attendance', 'FALSE ATTENDANCE'),
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: AppColors.r40,
                  fontSize: 22.sp,
                ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8.h),

          // Message text
          Text(
            languageProvider.getMessage(
                'marked_incorrectly', 'You marked attendance incorrectly'),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.n80,
                ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24.h),

          // Status indicators and progress bar
          Column(
            children: [
              // Top row with status indicators
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Provisional status
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        children: [
                          Container(
                            width: 36.r,
                            height: 36.r,
                            decoration: const BoxDecoration(
                              color: AppColors.g40,
                              shape: BoxShape.circle,
                            ),
                            padding: EdgeInsets.all(6.r),
                            child: FittedBox(
                              child: Icon(
                                Icons.check,
                                color: AppColors.n0,
                                size: 20.r,
                              ),
                            ),
                          ),
                          SizedBox(height: 10.h),
                          Text(
                            languageProvider
                                .getMessage(AppStrings.provisional,
                                    AppStrings.provisional)
                                .capitalize(),
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  color: AppColors.g40,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Morning status
                  Expanded(
                    child: Align(
                      alignment: Alignment.center,
                      child: Column(
                        children: [
                          Container(
                            width: 36.r,
                            height: 36.r,
                            decoration: const BoxDecoration(
                              color: AppColors.g40,
                              shape: BoxShape.circle,
                            ),
                            padding: EdgeInsets.all(6.r),
                            child: FittedBox(
                              child: Icon(
                                Icons.done,
                                color: AppColors.n0,
                                size: 20.r,
                              ),
                            ),
                          ),
                          SizedBox(height: 10.h),
                          Text(
                            languageProvider
                                .getMessage(
                                  AppStrings.morning,
                                  AppStrings.morning,
                                )
                                .capitalize(),
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  color: AppColors.g40,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Login status
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Column(
                        children: [
                          Text(
                            formatIndianCurrency(amount),
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.r50,
                                ),
                          ),
                          SizedBox(height: 7.h),
                          Container(
                            width: 36.r,
                            height: 36.r,
                            decoration: const BoxDecoration(
                              color: AppColors.r50,
                              shape: BoxShape.circle,
                            ),
                            padding: EdgeInsets.all(6.r),
                            child: FittedBox(
                              child: Icon(
                                Icons.close,
                                color: AppColors.n0,
                                size: 20.r,
                              ),
                            ),
                          ),
                          SizedBox(height: 10.h),
                          Text(
                            languageProvider
                                .getMessage(
                                  AppStrings.login,
                                  AppStrings.login,
                                )
                                .capitalize(),
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  color: AppColors.r50,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 8.h),

              // Custom progress slider
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 22.w),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Progress line
                    Container(
                      height: 4.h,
                      color: AppColors.n30,
                    ),

                    // Active progress
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: 0.5, // Half complete (2 out of 3 points)
                        child: Container(
                          height: 4.h,
                          color: AppColors.g40,
                        ),
                      ),
                    ),

                    // Progress dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildProgressDot(AppColors.g40),
                        // First point (completed)
                        _buildProgressDot(AppColors.g40),
                        // Second point (current)
                        _buildProgressDot(AppColors.n60),
                        // Third point (upcoming)
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressDot(Color color) {
    return Container(
      width: 8.w,
      height: 8.h,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: color),
      ),
    );
  }
}
