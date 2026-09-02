
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/utils/colors.dart';

/// Displays information about Ming eligibility status
class MingEligibilityInfo extends StatelessWidget {
  final List<dynamic> reasons;

  const MingEligibilityInfo({
    super.key,
    required this.reasons,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(builder: (context, languageProvider, _) {
      return Container(
        width: double.infinity,
        margin: EdgeInsets.only(top: 24.h),
        decoration: BoxDecoration(
          color: AppColors.n30,
          border: Border.all(color: AppColors.n50),
          borderRadius: BorderRadius.circular(8.r),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(30, 67, 102, 0.04),
              offset: Offset(0, 3),
              blurRadius: 10,
              spreadRadius: 3,
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(16.r),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.n10.withOpacity(0.7),
              borderRadius: BorderRadius.circular(8.r),
            ),
            padding: EdgeInsets.all(10.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF40515B), Color(0xFFA0A7AE)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                  padding:
                  EdgeInsets.symmetric(vertical: 10.h, horizontal: 10.w),
                  child: Row(
                    children: [
                      Container(
                        width: 16.w,
                        height: 16.h,
                        decoration: const BoxDecoration(
                          color: AppColors.n0,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            Icons.close,
                            size: 12.sp,
                            color: const Color(0xFF4D5D66),
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        languageProvider.getMessage(
                          "you_did_not_earn_ming",
                          "You did not earn MinG today",
                        ),
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                          color: AppColors.n0,
                          letterSpacing: -0.24,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  languageProvider.getMessage(
                    "not_eligible_ming_because",
                    "You were not eligible for MinG because:",
                  ),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.n80,
                  ),
                ),
                SizedBox(height: 8.h),
                if (reasons.isNotEmpty)
                  ...reasons.map((e) {
                    return Padding(
                      padding: EdgeInsets.only(bottom: 8.h),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.close,
                            size: 30.sp,
                            color: AppColors.r50,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            languageProvider.getMessage(
                                e.toString(), e.toString()),
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.r50,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      );
    });
  }
}
