import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/utils/colors.dart';

/// Risk-styled drawer entry that opens the Aadhaar re-KYC flow. Reuses the
/// app's risk-nudge palette (light-red fill + red border/text). [onTap] handles
/// navigation + the refresh-on-return.
class AadhaarRekycDrawerCard extends StatelessWidget {
  const AadhaarRekycDrawerCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final languageProvider = context.watch<LanguageProvider>();
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8.r),
        child: Container(
          padding: EdgeInsets.all(12.r),
          decoration: BoxDecoration(
            color: AppColors.nudgeRiskBg,
            border: Border.all(color: AppColors.nudgeRiskText, width: 1.r),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.badge_outlined,
                      size: 20.r, color: AppColors.nudgeRiskText),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      languageProvider.getMessage(
                          'aadhaar_rekyc_drawer_title', 'Update Aadhaar'),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14.sp,
                        letterSpacing: -0.24,
                        color: AppColors.nudgeRiskText,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right,
                      size: 20.r, color: AppColors.nudgeRiskText),
                ],
              ),
              SizedBox(height: 8.h),
              Text(
                languageProvider.getMessage('aadhaar_rekyc_drawer_subtitle',
                    'Update Aadhaar flows so your account stays active'),
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 12.sp,
                  letterSpacing: -0.24,
                  color: AppColors.nudgeRiskSubtitle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
