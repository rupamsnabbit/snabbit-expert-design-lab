import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/utils/colors.dart';

/// Engaging loading state while credentials are fetched and the Perfios URL is
/// built. Shows an inline retry when that setup fails.
class AadhaarReverificationLoadingView extends StatelessWidget {
  const AadhaarReverificationLoadingView({
    super.key,
    required this.credsError,
    required this.onRetry,
  });

  final bool credsError;
  final VoidCallback onRetry;

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
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: credsError
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline_rounded,
                          size: 64.r, color: AppColors.r50),
                      SizedBox(height: 16.h),
                      Text(
                        languageProvider.getMessage(
                            'aadhaar_rekyc_setup_failed',
                            'We could not start verification. Please try again.'),
                        textAlign: TextAlign.center,
                        style:
                            textTheme.bodyLarge?.copyWith(color: AppColors.n70),
                      ),
                      SizedBox(height: 24.h),
                      ElevatedButton(
                        onPressed: onRetry,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brand,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                        ),
                        child: Text(
                          languageProvider.getMessage('try_again', 'Try again'),
                          style: textTheme.labelLarge
                              ?.copyWith(color: AppColors.n0),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CupertinoActivityIndicator(),
                      SizedBox(height: 20.h),
                      Text(
                        languageProvider.getMessage(
                            'aadhaar_rekyc_loading_title',
                            'Setting up secure verification…'),
                        textAlign: TextAlign.center,
                        style: textTheme.titleMedium,
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        languageProvider.getMessage(
                            'aadhaar_rekyc_loading_subtitle',
                            'This can take a few moments. Please keep your '
                                'Aadhaar-linked mobile handy for the OTP.'),
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium
                            ?.copyWith(color: AppColors.n70),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
