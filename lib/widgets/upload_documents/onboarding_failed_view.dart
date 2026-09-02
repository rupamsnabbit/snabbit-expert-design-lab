import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/document_error_models.dart';
import 'package:snabbit_runner/models/onboarding_question_data.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/onboarding_steps_provider.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/extensions/cdn_extensions.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';

class OnboardingFailedView extends StatefulWidget {
  static const String routeName = "/onboarding-failed-view";

  const OnboardingFailedView({
    super.key,
    this.onboardingFailedData,
  });

  final OnboardingFailedData? onboardingFailedData;

  @override
  State<OnboardingFailedView> createState() => _OnboardingFailedViewState();
}

class _OnboardingFailedViewState extends State<OnboardingFailedView> {
  bool init = true;
  late LanguageProvider languageProvider;
  late OnboardingStepsProvider onboardingStepsProvider;
  late OnboardingFailedData? failedData;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      onboardingStepsProvider =
          Provider.of<OnboardingStepsProvider>(context, listen: true);
      failedData = widget.onboardingFailedData ??
          onboardingStepsProvider.onboardingFailedData;
    }
    super.didChangeDependencies();
  }

  OnboardingQuestionResponse? get onboardingQuestionResponse =>
      onboardingStepsProvider.onboardingQuestionResponse;

  int? get sessionId => onboardingQuestionResponse?.sessionId;

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
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildErrorIcon(),
                    SizedBox(height: 24.h),
                    _buildErrorTitle(textTheme),
                    SizedBox(height: 12.h),
                    _buildErrorMessage(textTheme),
                    SizedBox(height: 32.h),
                    _buildRetryMessage(textTheme),
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
      imageUrl: failedData?.imageUrl?.cdn ?? '',
      width: 140.r,
      errorWidget: const SizedBox(),
    );
  }

  Widget _buildErrorTitle(TextTheme textTheme) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 25.w),
      child: SizedBox(
        width: double.infinity,
        child: Text(failedData?.title ?? '',
            textAlign: TextAlign.center,
            style: textTheme.displayMedium?.copyWith(
              fontSize: 21.sp,
              color: AppColors.n90,
            )),
      ),
    );
  }

  Widget _buildErrorMessage(TextTheme textTheme) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 25.w),
      child: SizedBox(
        width: double.infinity,
        child: Text(
          failedData?.message ?? '',
          textAlign: TextAlign.center,
          style: textTheme.titleSmall
              ?.copyWith(color: AppColors.n70, fontSize: 16.sp),
        ),
      ),
    );
  }

  Widget _buildRetryMessage(TextTheme textTheme) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 14.5.h),
      color: AppColors.r10,
      child: SizedBox(
        width: double.infinity,
        child: Text(
          failedData?.retryMessage ?? '',
          textAlign: TextAlign.center,
          style: textTheme.displaySmall
              ?.copyWith(color: AppColors.r50, fontSize: 16.sp),
        ),
      ),
    );
  }
}
