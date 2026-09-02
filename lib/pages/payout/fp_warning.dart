import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/widgets/payout/current_period_view.dart';

import '../../constants/assets_constants.dart';
import '../../providers/daily_earnings.dart';
import '../../utils/colors.dart';
import '../../utils/common_methods.dart';
import 'daily_earnings_list.dart';

class FPWarningView extends StatefulWidget {
  const FPWarningView({super.key});

  @override
  State<FPWarningView> createState() => _FPWarningViewState();
}

class _FPWarningViewState extends State<FPWarningView> {
  bool init = true;
  late LanguageProvider languageProvider;
  late UserProfileProvider userProfileProvider;
  late CurrentPeriodProvider currentPeriodProvider;
  late DailyEarningsListProvider earningsListProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: true);
      currentPeriodProvider =
          Provider.of<CurrentPeriodProvider>(context, listen: true);
      earningsListProvider =
          Provider.of<DailyEarningsListProvider>(context, listen: true);
    }
  }

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
          // Warning icon
          Image.asset(
            AssetConstants.fpWarningPng,
            height: 67.r,
          ),
          SizedBox(height: 32.h),

          // Warning text
          Text(
            languageProvider.getMessage('warning', 'Warning'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.n90,
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w600,
                ),
            textAlign: TextAlign.center,
          ),
          Text(
            languageProvider.getMessage(
                'false_attendance_capital', 'FALSE ATTENDANCE'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.n90,
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w800,
                ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20.h),

          // Warning message
          Text(
            languageProvider.getFormattedMessage(
              'fp1_penalty_warning',
              '₹{{applicable_penalty}} penalty will be applied next time',
              {
                'applicable_penalty': userProfileProvider
                    .user?.runnerAppConfig?.payoutConfig?.fpPenalty,
              },
            ),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.n80,
                  fontWeight: FontWeight.w700,
                ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24.h),

          // Bottom banner
          Container(
            width: double.infinity,
            height: 42.h,
            decoration: BoxDecoration(
              color: AppColors.n20,
              borderRadius: BorderRadius.circular(8.r),
            ),
            alignment: Alignment.center,
            child: Text(
              languageProvider.getMessage(
                  'first_final_warning', 'First & Final warning this month!'),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.n70,
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
