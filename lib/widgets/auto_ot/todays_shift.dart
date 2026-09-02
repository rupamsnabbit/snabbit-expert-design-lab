import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/auto_ot_provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/enums.dart';

class TodaysShiftView extends StatelessWidget {
  final OtType otType;

  const TodaysShiftView({
    super.key,
    this.otType = OtType.EndOt,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer2<AutoOtProvider, LanguageProvider>(
        builder: (context, provider, languageProvider, _) {
      final details = provider.details;
      final regularShift = details?.regularShift;
      final String message = otType == OtType.StartOt
          ? languageProvider.getMessage('tomorrows_shift', 'Tomorrow\'s shift')
          : languageProvider.getMessage('todays_shift', 'Today\'s shift');
      return Container(
        height: 82.h,
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppColors.n30.withValues(alpha: 0.5),
          border: Border.all(color: AppColors.n10, width: 1),
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Row(
          children: [
            // Clock icon
            Icon(
              Icons.access_time,
              size: 24.r,
              color: AppColors.n80,
            ),
            SizedBox(width: 10.w),
            // Shift details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    message,
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          height: 14 / 14,
                          color: AppColors.n80,
                          letterSpacing: -0.24,
                        ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    provider.formatTimeRange(
                        regularShift?.startTime, regularShift?.endTime),
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.w700,
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
                  languageProvider.getMessage('min_g', 'Min G'),
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        height: 14 / 14,
                        color: AppColors.n80,
                        letterSpacing: -0.24,
                      ),
                ),
                SizedBox(height: 4.h),
                Text(
                  formatIndianCurrency(anyValueToInt(regularShift?.ming)),
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
