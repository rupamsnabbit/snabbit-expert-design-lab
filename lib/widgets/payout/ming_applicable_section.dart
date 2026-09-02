import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/models/daily_earnings_models.dart';
import 'package:snabbit_runner/services/custom_text/custom_text.dart';

import '../../providers/daily_earnings_provider.dart';
import '../../utils/colors.dart';

class MingApplicableSection extends StatelessWidget {
  const MingApplicableSection({
    super.key,
  });

  bool _isMingEarned(DailyEarningsResponse? dailyEarnings) {
    try {
      return dailyEarnings?.basePay?.totalBasePay != null &&
          dailyEarnings?.mingAmount != null &&
          dailyEarnings!.basePay!.totalBasePay! < dailyEarnings.mingAmount!;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DailyEarningsProvider>(
        builder: (context, earningsProvider, _) {
      return Consumer<LanguageProvider>(
        builder: (context, languageProvider, _) {
          return Container(
            padding: EdgeInsets.all(10.r),
            decoration: BoxDecoration(
              color: earningsProvider.dailyEarningsData?.mingEligible == true
                  ? const Color(0xFFF6F0FF)
                  : const Color(0xffFCFCFC).withOpacity(0.7),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      EdgeInsets.symmetric(vertical: 10.h, horizontal: 10.w),
                  decoration: BoxDecoration(
                    gradient:
                        earningsProvider.dailyEarningsData?.mingEligible == true
                            ? const LinearGradient(
                                colors: [
                                  Color(0xFF6832BB),
                                  Color(0xFF101840),
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              )
                            : const LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Color(0xFF40515B), // #40515B
                                  Color(0xFFA0A7AE), // #A0A7AE
                                ],
                              ),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                  child: Row(
                    children: [
                      if (earningsProvider.dailyEarningsData?.mingEligible ==
                          true)
                        Icon(
                          Icons.check_circle,
                          color: AppColors.n0,
                          size: 16.sp,
                        )
                      else
                        Icon(
                          Icons.cancel,
                          color: AppColors.n0,
                          size: 16.sp,
                        ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              earningsProvider
                                          .dailyEarningsData?.mingEligible ==
                                      true
                                  ? _isMingEarned(
                                          earningsProvider.dailyEarningsData)
                                      ? languageProvider.getMessage(
                                          'ming_earned',
                                          'MinG Earned',
                                        )
                                      : languageProvider.getMessage(
                                          'ming_eligible',
                                          'MinG eligible',
                                        )
                                  : languageProvider.getMessage(
                                      'ming_not_applicable',
                                      'MinG not applicable ',
                                    ),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.n0),
                            ),
                            if (_isMingEarned(
                                earningsProvider.dailyEarningsData))
                              Text(
                                "₹${earningsProvider.dailyEarningsData?.mingAmount}",
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppColors.n0),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  languageProvider.getMessage('you_are_guaranteed_ming',
                      'You are guaranteed MinG When:'),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.n80,
                      ),
                ),
                SizedBox(height: 8.h),

                // If we have ming details, display them
                if (earningsProvider.dailyEarningsData?.mingDetails != null &&
                    earningsProvider.dailyEarningsData!.mingDetails!.isNotEmpty)
                  ...earningsProvider.dailyEarningsData!.mingDetails!
                      .map((detail) => _buildDetailItem(
                            context,
                            languageProvider.getMessage(
                                detail.key ?? '', detail.key ?? ''),
                            detail.value ?? false,
                    details: detail.details,
                          ),
                  ),
              ],
            ),
          );
        },
      );
    });
  }

  Widget _buildDetailItem(BuildContext context, String text, bool isValid,
      {List<dynamic>? details}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isValid ? Icons.check : Icons.close,
                color: isValid ? const Color(0xFF316729) : AppColors.r50,
                size: isValid ? 10.r : 30.r,
              ),
              SizedBox(width: 4.w),
              if (isValid)
                Text(
                  text,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: AppColors.n80,
                      ),
                )
              else
                Text(
                  text,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.r50,
                      ),
                ),
            ],
          ),
          details?.isNotEmpty == true
              ? Padding(
                  padding: EdgeInsets.only(left: 9.w),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: details!
                          .map((detail) => CustomText(textData: detail))
                          .toList()),
                )
              : const SizedBox(),
        ],
      ),
    );
  }
}
