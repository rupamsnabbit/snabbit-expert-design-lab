import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/widgets/payout/current_period_view.dart';

import '../../constants/assets_constants.dart';
import '../../providers/daily_earnings.dart';
import '../../utils/colors.dart';
import 'daily_earnings_list.dart';

class NoShowWarningView extends StatefulWidget {
  const NoShowWarningView({super.key});

  @override
  State<NoShowWarningView> createState() => _NoShowWarningViewState();
}

class _NoShowWarningViewState extends State<NoShowWarningView> {
  bool init = true;
  late LanguageProvider languageProvider;
  late CurrentPeriodProvider currentPeriodProvider;
  late DailyEarningsListProvider earningsListProvider;

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
            languageProvider.getMessage(
                'warning', 'Warning'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.n90,
              fontSize: 22.sp,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            languageProvider.getMessage(
                'no_show_capital', 'NO SHOW'),
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
            languageProvider.getMessage('make_sure_to_login',
                'Please make sure to login next time'),
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
                  'given_strict_warning', 'You have been given a strict warning!'),
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
