import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/utils/colors.dart';

/// Initial messaging shown before the runner starts the re-KYC flow.
class AadhaarReverificationIntroView extends StatelessWidget {
  const AadhaarReverificationIntroView({super.key, required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final languageProvider = context.watch<LanguageProvider>();
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.n0,
      appBar: AppBar(
        foregroundColor: AppColors.n90,
        title: Text(
          languageProvider.getMessage(
              'aadhaar_rekyc_title', 'Aadhaar verification'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/webp/aadhaar_re_kyc.webp',
                      width: 160.r,
                      height: 160.r,
                    ),
                    SizedBox(height: 24.h),
                    Text(
                      languageProvider.getMessage(
                          'aadhaar_rekyc_intro_title', 'Verify your Aadhaar'),
                      textAlign: TextAlign.center,
                      style: textTheme.headlineMedium,
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      languageProvider.getMessage(
                          'aadhaar_rekyc_intro_message',
                          'To continue working, please re-verify your Aadhaar. '
                              "You'll confirm an OTP — it takes about a minute."),
                      textAlign: TextAlign.center,
                      style:
                          textTheme.bodyLarge?.copyWith(color: AppColors.n70),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 48.h,
                child: ElevatedButton(
                  onPressed: onStart,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  child: Text(
                    languageProvider.getMessage(
                        'aadhaar_rekyc_start', 'Start verification'),
                    style: textTheme.labelLarge?.copyWith(color: AppColors.n0),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
            ],
          ),
        ),
      ),
    );
  }
}
