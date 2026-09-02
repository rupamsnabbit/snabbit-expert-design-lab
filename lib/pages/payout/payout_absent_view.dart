import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/widgets/common_app_bar.dart';
import 'package:snabbit_runner/widgets/payout/current_period_view.dart';

import '../../constants/assets_constants.dart';
import '../../utils/common_methods.dart';

class PayoutAbsentView extends StatefulWidget {

  const PayoutAbsentView({super.key});

  @override
  State<PayoutAbsentView> createState() => _PayoutAbsentViewState();
}

class _PayoutAbsentViewState extends State<PayoutAbsentView> {
  bool init = true;
  late LanguageProvider languageProvider;
  late CurrentPeriodProvider currentPeriodProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      currentPeriodProvider =
          Provider.of<CurrentPeriodProvider>(context, listen: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AbsentDayPanel(
      date: currentPeriodProvider.currentDate,
      languageProvider: languageProvider,
    );
  }
}

class AbsentDayPanel extends StatelessWidget {
  final DateTime date;
  final LanguageProvider languageProvider;

  const AbsentDayPanel({
    super.key,
    required this.date,
    required this.languageProvider,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormatter =
        DateFormat('EEEE d\'${getDaySuffix(date.day)}\' MMMM');
    final formattedDate = dateFormatter.format(date);

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
          // Cancel icon
          Container(
            width: 67.r,
            height: 67.r,
            decoration: const BoxDecoration(
              color: Color(0xffF15249),
              shape: BoxShape.circle,
            ),
            padding: EdgeInsets.all(16.r),
            child: FittedBox(child: Image.asset(AssetConstants.crossPng)),
          ),
          SizedBox(height: 24.h),

          // Absent text
          Text(
            languageProvider.getMessage('absent', 'ABSENT'),
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: AppColors.r40,
                  fontSize: 22.sp,
                ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8.h),

          // No earnings message
          Text(
            languageProvider.getMessage(
                'no_earnings_for_date', 'You don\'t have any earnings for'),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.n80,
                ),
            textAlign: TextAlign.center,
          ),
          Text(
            formattedDate,
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: AppColors.n80,
                ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 47.h),

          // Bottom banner
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              vertical: 12.h,
              horizontal: 24.5.w,
            ),
            decoration: BoxDecoration(
              color: AppColors.n20,
              borderRadius: BorderRadius.circular(8.r),
            ),
            alignment: Alignment.center,
            child: Text(
              languageProvider.getMessage(
                'being_present_helps',
                'Being present helps you earn more',
              ),
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: AppColors.n70),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
