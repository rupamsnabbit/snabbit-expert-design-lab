import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/aadhaar_update_response.dart';
import 'package:snabbit_runner/models/errors/custom_error.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/utils/colors.dart';

/// Presentational result screen for the Aadhaar re-KYC flow. Driven entirely by
/// the [result] status (the bare 200 body) or the [error] (non-200, surfaced as
/// a [CustomError] — same as the current Aadhaar flow). [canRetry] decides
/// whether a "Try again" action is offered.
class AadhaarReverificationResultView extends StatelessWidget {
  const AadhaarReverificationResultView({
    super.key,
    required this.result,
    required this.error,
    required this.canRetry,
    required this.onRetry,
    required this.onDone,
  });

  final AadhaarUpdateResponse? result;
  final CustomError? error;
  final bool canRetry;
  final VoidCallback onRetry;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final languageProvider = context.watch<LanguageProvider>();
    final textTheme = Theme.of(context).textTheme;
    final visuals = _resolveVisuals(languageProvider);

    return Scaffold(
      backgroundColor: AppColors.n0,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(visuals.icon, size: 96.r, color: visuals.color),
                    SizedBox(height: 24.h),
                    Text(
                      visuals.title,
                      textAlign: TextAlign.center,
                      style: textTheme.headlineMedium,
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      visuals.message,
                      textAlign: TextAlign.center,
                      style:
                          textTheme.bodyLarge?.copyWith(color: AppColors.n70),
                    ),
                  ],
                ),
              ),
              _ResultActions(
                canRetry: canRetry,
                onRetry: onRetry,
                onDone: onDone,
              ),
              SizedBox(height: 16.h),
            ],
          ),
        ),
      ),
    );
  }

  _ResultVisuals _resolveVisuals(LanguageProvider languageProvider) {
    final result = this.result;
    if (result != null && result.isVerified) {
      return _ResultVisuals(
        icon: Icons.check_circle_rounded,
        color: AppColors.g50,
        title: languageProvider.getMessage(
            'aadhaar_rekyc_verified_title', 'Aadhaar verified'),
        message: languageProvider.getMessage('aadhaar_rekyc_verified_message',
            'Your Aadhaar has been verified successfully.'),
      );
    }
    if (result != null && result.isNameMismatched) {
      return _ResultVisuals(
        icon: Icons.hourglass_top_rounded,
        color: AppColors.y50,
        title: languageProvider.getMessage(
            'aadhaar_rekyc_review_title', 'Under review'),
        message: languageProvider.getMessage(
            'aadhaar_rekyc_review_message',
            "Your details don't match our records, so this has been sent for "
                "manual review. We'll update you shortly."),
      );
    }
    // rejected status, an unknown status, or a backend/local error.
    return _ResultVisuals(
      icon: Icons.error_rounded,
      color: AppColors.r50,
      title: error?.title ??
          languageProvider.getMessage(
              'aadhaar_rekyc_failed_title', 'Verification failed'),
      message: error?.message ??
          languageProvider.getMessage('aadhaar_rekyc_failed_message',
              "We couldn't verify your Aadhaar. Please try again."),
    );
  }
}

class _ResultVisuals {
  _ResultVisuals({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String message;
}

/// Footer actions: a single "Done" for terminal outcomes, or "Try again" +
/// "Close" when the outcome is retryable.
class _ResultActions extends StatelessWidget {
  const _ResultActions({
    required this.canRetry,
    required this.onRetry,
    required this.onDone,
  });

  final bool canRetry;
  final VoidCallback onRetry;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final languageProvider = context.watch<LanguageProvider>();

    if (!canRetry) {
      return _PrimaryButton(
        label: languageProvider.getMessage('done', 'Done'),
        onPressed: onDone,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PrimaryButton(
          label: languageProvider.getMessage('try_again', 'Try again'),
          onPressed: onRetry,
        ),
        SizedBox(height: 8.h),
        TextButton(
          onPressed: onDone,
          child: Text(languageProvider.getMessage('close', 'Close')),
        ),
      ],
    );
  }
}

/// Full-width branded primary button used by the result actions.
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48.h,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brand,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.r),
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(color: AppColors.n0),
        ),
      ),
    );
  }
}
