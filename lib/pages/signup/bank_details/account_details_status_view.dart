import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/onboarding_question_data.dart';
import 'package:snabbit_runner/pages/signup/onboarding_progress_bar.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/onboarding_steps_provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/extensions/cdn_extensions.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';

enum AccountVerificationStatus {
  success,
  failure,
}

class AccountDetailsStatusView extends StatefulWidget {
  static const String routeName = "/account-details-status-view";

  final AccountVerificationStatus status;
  final PayoutOption? payoutOption;

  const AccountDetailsStatusView({
    super.key,
    required this.status,
    this.payoutOption,
  });

  @override
  State<AccountDetailsStatusView> createState() =>
      _AccountDetailsStatusViewState();
}

class _AccountDetailsStatusViewState extends State<AccountDetailsStatusView> {
  bool init = true;
  late LanguageProvider languageProvider;
  late OnboardingStepsProvider onboardingStepsProvider;
  late UserProfileProvider userProfileProvider;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      onboardingStepsProvider =
          Provider.of<OnboardingStepsProvider>(context, listen: true);
      userProfileProvider =
          Provider.of<UserProfileProvider>(context, listen: false);
    }
    super.didChangeDependencies();
  }

  OnboardingQuestionGroup? get currentQuestionGroup =>
      onboardingStepsProvider.currentQuestionsData;

  OnboardingQuestionResponse? get onboardingQuestionResponse =>
      onboardingStepsProvider.onboardingQuestionResponse;

  OnboardingQuestionGroupUIConfig? get currentQuestionGroupUIConfig =>
      currentQuestionGroup?.uiConfig;

  int? get sessionId => onboardingQuestionResponse?.sessionId;

  int get _currentIndex =>
      onboardingQuestionResponse?.currentQuestionNumber ?? 0;

  int get _totalSteps => onboardingQuestionResponse?.totalQuestions ?? 0;

  double get _progressValue =>
      _totalSteps == 0 ? 0 : _currentIndex / _totalSteps;

  // Hardcoded content based on verification status
  String get _statusIcon {
    switch (widget.status) {
      case AccountVerificationStatus.success:
        return 'onboarding/banking_success_icon.png'.cdn;
      case AccountVerificationStatus.failure:
        return 'onboarding/banking_error_icon.png'.cdn;
    }
  }

  String get _statusTitle {
    switch (widget.status) {
      case AccountVerificationStatus.success:
        return languageProvider.getMessage('thank_you', 'Thank You!');
      case AccountVerificationStatus.failure:
        return languageProvider.getMessage(
            'verification_failed', 'Verification Failed');
    }
  }

  String get _statusMessage {
    switch (widget.status) {
      case AccountVerificationStatus.success:
        if (widget.payoutOption == PayoutOption.upi) {
          return languageProvider.getMessage(
              'upi_verification_successful_message',
              'UPI details successfully uploaded');
        } else {
          return languageProvider.getMessage('verification_successful_message',
              'Bank details successfully uploaded');
        }
      case AccountVerificationStatus.failure:
        return languageProvider.getMessage('verification_failed_message',
            'Retry verification or add a new account');
    }
  }

  String get _ctaButtonText {
    switch (widget.status) {
      case AccountVerificationStatus.success:
        return 'Okay';
      case AccountVerificationStatus.failure:
        return 'Retry';
    }
  }

  void performActionOnCtaTap(String? task) {
    if (task == null) return;

    final sessionId = onboardingQuestionResponse?.sessionId;

    if (sessionId == null) return;

    // Build the payload with session_id and action
    final payload = {
      "session_id": sessionId,
      "action": task,
    };

    // Call performAction with the payload
    onboardingStepsProvider.performAction(
      context: context,
      data: payload,
      navigateOnSuccess: true,
    );
  }

  Future<void> _handleCtaButtonTap() async {
    switch (widget.status) {
      case AccountVerificationStatus.success:
        await _handleSuccessAction();
        break;
      case AccountVerificationStatus.failure:
        _handleRetryAction();
        break;
    }
  }

  Future<void> _handleSuccessAction() async {
    await userProfileProvider.checkStatusAndNavigate(context);
  }

  void _handleRetryAction() {
    // Clear the navigation stack back to the payout option screen and go to details screen
    // This ensures that when user taps back from details screen, they go to option picker
    final routeName = widget.payoutOption == PayoutOption.upi
        ? '/enter_upi_details'
        : '/enter_bank_details';

    Navigator.of(context).pushNamedAndRemoveUntil(
      routeName,
      (route) => route.settings.name == '/add_bank_or_upi_details',
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (onboardingStepsProvider.loading) {
      return Scaffold(
        backgroundColor: AppColors.n0,
        body: const Center(
          child: CupertinoActivityIndicator(),
        ),
      );
    }
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.n0,
        appBar: AppBar(elevation: 6),
        persistentFooterButtons: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: SizedBox(
              width: double.infinity,
              height: 48.h,
              child: ElevatedButton(
                onPressed: onboardingStepsProvider.loading
                    ? null
                    : _handleCtaButtonTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                child: onboardingStepsProvider.loading
                    ? const CupertinoActivityIndicator(color: Colors.white)
                    : Text(
                        _ctaButtonText,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: Colors.white,
                            ),
                      ),
              ),
            ),
          ),
        ],
        body: SafeArea(
          child: Column(
            children: [
              SizedBox(height: 6.h),
              OnboardingProgressBar(progressValue: _progressValue),
              SizedBox(height: 33.h),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 74.h,
                    ),
                    _buildErrorIcon(),
                    SizedBox(height: 16.h),
                    _buildErrorTitle(textTheme),
                    SizedBox(height: 12.h),
                    _buildErrorMessage(textTheme),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorIcon() {
    return RemoteImageHandler(
      imageUrl: _statusIcon,
      width: 48.r,
      errorWidget: const SizedBox(),
    );
  }

  Widget _buildErrorTitle(TextTheme textTheme) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 44.w),
      child: Text(_statusTitle,
          textAlign: TextAlign.center, style: textTheme.headlineMedium),
    );
  }

  Widget _buildErrorMessage(TextTheme textTheme) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 44.w),
      child: Text(
        _statusMessage,
        textAlign: TextAlign.center,
        style: textTheme.bodyLarge?.copyWith(
          color: AppColors.n70,
        ),
      ),
    );
  }
}
