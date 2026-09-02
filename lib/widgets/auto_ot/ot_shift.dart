import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/auto_ot_provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';

class OtShiftView extends StatelessWidget {
  const OtShiftView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<AutoOtProvider, LanguageProvider>(
        builder: (context, provider, languageProvider, _) {
      final details = provider.details;
      final otShift = details?.otShift;
      return Container(
        height: 82.h,
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppColors.g10,
          border: Border.all(color: AppColors.g30, width: 2),
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 0),
            ),
          ],
        ),
        child: Row(
          children: [
            // Clock icon (green)
            Icon(
              Icons.access_time,
              size: 24.r,
              color: AppColors.g40,
            ),
            SizedBox(width: 10.w),
            // Shift details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  //convert to RichText
                  RichText(
                      text: TextSpan(
                          style:
                              Theme.of(context).textTheme.displaySmall?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    height: 14 / 14,
                                    color: AppColors.n80,
                                    letterSpacing: -0.24,
                                  ),
                          children: [
                        TextSpan(
                          text:
                              '${languageProvider.getMessage('Work', 'Work')} ',
                        ),
                        TextSpan(
                            text:
                                '${otShift?.duration} ${languageProvider.getMessage('hours', 'hours')} ',
                            style: Theme.of(context)
                                .textTheme
                                .displayMedium
                                ?.copyWith(
                                  height: 14 / 14,
                                  color: AppColors.n80,
                                  letterSpacing: -0.24,
                                )),
                        TextSpan(
                          text: languageProvider.getMessage('extra', 'extra'),
                        ),
                      ])),
                  SizedBox(height: 4.h),
                  Text(
                    provider.formatTimeRange(
                        otShift?.startTime, otShift?.endTime),
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          fontSize: 16.sp,
                          height: 16 / 16,
                          color: AppColors.autoOtTextPrimary,
                          letterSpacing: -0.24,
                        ),
                  ),
                ],
              ),
            ),
            // Earnings
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  languageProvider.getMessage('new_min_g', 'New Min G'),
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        height: 14 / 14,
                        color: AppColors.n80,
                        letterSpacing: -0.24,
                      ),
                ),
                SizedBox(height: 4.h),
                Text(
                  formatIndianCurrency(anyValueToInt(otShift?.ming)),
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        fontSize: 16.sp,
                        height: 16 / 16,
                        color: AppColors.autoOtTextPrimary,
                        letterSpacing: -0.24,
                      ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }
}
