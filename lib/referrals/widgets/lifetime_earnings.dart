import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/mixins/provider_initialization_mixin.dart';

class LifetimeEarnings extends StatefulWidget {
  const LifetimeEarnings({super.key});

  @override
  State<LifetimeEarnings> createState() => _LifetimeEarningsState();
}

class _LifetimeEarningsState extends State<LifetimeEarnings>
    with ProviderInitializationMixin {
  @override
  void didChangeDependencies() {
    initializeCommonProviders();
    super.didChangeDependencies();
  }

  bool get hasReferrals => (referralDataProvider.referralData?.totalReferrals ?? 0) > 0;

  @override
  Widget build(BuildContext context) {
    if (referralDataProvider.referralData == null) return const SizedBox.shrink();
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.r),
        color: AppColors.n0,
        boxShadow: [
          BoxShadow(
            color: AppColors.n90.withOpacity(0.25),
            offset: const Offset(0, 1),
            blurRadius: 2.r,
            spreadRadius: 0,
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(vertical: 32.h, horizontal: 29.w),
      child: Row(
        mainAxisAlignment: hasReferrals ? MainAxisAlignment.spaceBetween : MainAxisAlignment.center,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: hasReferrals ? CrossAxisAlignment.start : CrossAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    languageProvider.getMessage(
                        'lifetime_earnings', 'Lifetime Earnings'),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                SizedBox(height: 4.h),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    formatIndianCurrency(
                        referralDataProvider.referralData?.totalEarnings),
                    style: Theme.of(context)
                        .textTheme
                        .displayLarge
                        ?.copyWith(color: const Color(0xff26A179)),
                  ),
                ),
              ],
            ),
          ),
          if (hasReferrals)
            SizedBox(width: 8.w),
          if (hasReferrals)
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      languageProvider.getMessage(
                          'successful_referrals', 'Successful Referrals'),
                      style: Theme.of(context)
                          .textTheme
                          .displaySmall
                          ?.copyWith(color: AppColors.n90),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      referralDataProvider.referralData?.totalReferrals
                              ?.toString() ??
                          "",
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontSize: 18.sp),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
