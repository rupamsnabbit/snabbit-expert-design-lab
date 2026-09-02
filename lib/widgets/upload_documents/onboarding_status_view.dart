import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/document_error_models.dart';
import 'package:snabbit_runner/models/onboarding_question_data.dart';
import 'package:snabbit_runner/pages/signup/onboarding_progress_bar.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/onboarding_steps_provider.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/extensions/cdn_extensions.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';
import 'package:snabbit_runner/widgets/upload_documents/onboarding_callout.dart';
import 'package:snabbit_runner/widgets/upload_documents/onboarding_status_cta_buttons.dart';

class OnboardingStatusView extends StatefulWidget {
  static const String routeName = "/onboarding-status-view";

  const OnboardingStatusView({
    super.key,
    this.onboardingStatusData,
    this.onProceed,
    this.onRetry,
    this.onVerifyVoterId,
  });

  final OnboardingStatusData? onboardingStatusData;
  final VoidCallback? onProceed;
  final VoidCallback? onRetry;
  final VoidCallback? onVerifyVoterId;

  @override
  State<OnboardingStatusView> createState() => _OnboardingStatusViewState();
}

class _OnboardingStatusViewState extends State<OnboardingStatusView> {
  bool init = true;
  late LanguageProvider languageProvider;
  late OnboardingStepsProvider onboardingStepsProvider;
  late OnboardingStatusData? statusData;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      onboardingStepsProvider =
          Provider.of<OnboardingStepsProvider>(context, listen: true);
      statusData = widget.onboardingStatusData ??
          onboardingStepsProvider.onboardingStatusData;
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
          OnboardingStatusCtaButtons(
            actions: statusData?.nextStep?.actions,
            onActionTap: performActionOnCtaTap,
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
                    SizedBox(height: 32.h),
                    OnboardingCallout(callOut: statusData?.status?.callOutData),
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
      imageUrl: statusData?.status?.icon?.cdn ?? '',
      width: 48.r,
      errorWidget: const SizedBox(),
    );
  }

  Widget _buildErrorTitle(TextTheme textTheme) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 44.w),
      child: Text(statusData?.status?.title ?? '',
          textAlign: TextAlign.center, style: textTheme.headlineMedium),
    );
  }

  Widget _buildErrorMessage(TextTheme textTheme) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 44.w),
      child: Text(
        statusData?.status?.subtitle ?? '',
        textAlign: TextAlign.center,
        style: textTheme.bodyLarge?.copyWith(
          color: AppColors.n70,
        ),
      ),
    );
  }
}
