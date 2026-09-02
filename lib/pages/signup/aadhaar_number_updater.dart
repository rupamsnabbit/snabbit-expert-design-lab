import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/document_error_models.dart';
import 'package:snabbit_runner/models/onboarding_question_data.dart';
import 'package:snabbit_runner/pages/signup/onboarding_progress_bar.dart';
import 'package:snabbit_runner/pages/signup/pan_number_updater.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/onboarding_steps_provider.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/custom_themes/text_themes.dart';
import 'package:snabbit_runner/widgets/onboarding_question.dart';
import 'package:snabbit_runner/widgets/upload_documents/onboarding_callout.dart';
import 'package:snabbit_runner/widgets/upload_documents/onboarding_status_view.dart';

class AadhaarNumberUpdater extends StatefulWidget {
  static const String routeName = "/aadhaar-number_updater";

  const AadhaarNumberUpdater({super.key});

  @override
  State<AadhaarNumberUpdater> createState() => _AadhaarNumberUpdaterState();
}

class _AadhaarNumberUpdaterState extends State<AadhaarNumberUpdater> {
  final TextEditingController aadhaarController = TextEditingController();
  dynamic errorAadhaar;
  dynamic docAadhaarUploadErr;
  bool init = true;
  late LanguageProvider languageProvider;
  late OnboardingStepsProvider onboardingStepsProvider;
  OnboardingStatusData? _onBoardingStatusData;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      onboardingStepsProvider =
          Provider.of<OnboardingStepsProvider>(context, listen: true);
      aadhaarController.text =
          currentQuestion?.previousResponse?.first.freeTextAnswer ?? '';

      languageProvider = Provider.of<LanguageProvider>(context, listen: true);

      setState(() {});
    }
    super.didChangeDependencies();
  }

  OnboardingQuestionResponse? get onboardingQuestionResponse =>
      onboardingStepsProvider.onboardingQuestionResponse;

  OnboardingQuestionGroup? get onboardingQuestionGroupGroup =>
      onboardingStepsProvider.currentQuestionsData;

  OnboardingQuestionGroupUIConfig? get onboardingQuestionGroupUiConfig =>
      onboardingQuestionGroupGroup?.uiConfig;

  OnboardingQuestionData? get currentQuestion =>
      onboardingQuestionResponse?.questions?.first;

  int? get sessionId => onboardingQuestionResponse?.sessionId;

  int get _currentIndex =>
      onboardingQuestionResponse?.currentQuestionNumber ?? 0;

  int get _totalSteps => onboardingQuestionResponse?.totalQuestions ?? 0;

  double get _progressValue =>
      _totalSteps == 0 ? 0 : _currentIndex / _totalSteps;

  @override
  Widget build(BuildContext context) {
    AadhaarDetailsUiConfig? uiConfigData;
    try {
      uiConfigData =
          AadhaarDetailsUiConfig.fromJson(currentQuestion?.uiConfig ?? {});
    } catch (_) {}

    // Try to get navActions from question group UI config meta if not in question UI config
    NavActions? navActions = uiConfigData?.navActions;
    if (navActions == null) {
      try {
        final meta = onboardingQuestionGroupUiConfig?.meta;
        if (meta != null && meta['nav_actions'] != null) {
          navActions = NavActions.fromJson(meta['nav_actions']);
        }
      } catch (_) {}
    }

    return Scaffold(
      appBar: AppBar(
        elevation: 6,
        leading: InkWell(
          onTap: () => onboardingStepsProvider.goBackToPreviousQuestion(
              context, onboardingQuestionResponse!.moduleId!),
          child: const Icon(
            Icons.arrow_back_ios_rounded,
            color: AppColors.n80,
          ),
        ),
      ),
      persistentFooterButtons: [
        SizedBox(
          width: 1.sw,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: onboardingQuestionGroupUiConfig?.ctaColor ??
                    AppColors.brand),
            onPressed: () {
              if (sessionId == null || currentQuestion == null) return;
              final Map<String, dynamic> response = {
                "question_id": currentQuestion?.id,
                "question_type": currentQuestion?.questionType,
                "free_text_answer": aadhaarController.text,
              };
              // Build the payload dynamically from all answers
              final payload = {
                "session_id": sessionId,
                "responses": [
                  response,
                ],
              };

              onboardingStepsProvider.submitAnswerAndProceed(
                context: context,
                data: payload,
                onSuccess: () {
                  //todo: handle success
                },
                onError: (error) {
                  try {
                    _onBoardingStatusData =
                        OnboardingStatusData.fromJson(error.data);
                  } catch (_) {}
                },
              );
            },
            child: Text(
              onboardingQuestionGroupUiConfig?.ctaText ?? "Continue",
            ),
          ),
        ),
      ],
      body: onboardingStepsProvider.loading
          ? Center(child: CupertinoActivityIndicator())
          : _onBoardingStatusData != null
              ? OnboardingStatusView(
                  onboardingStatusData: _onBoardingStatusData)
              : GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 6.h),
                        OnboardingProgressBar(progressValue: _progressValue),
                        SizedBox(height: 33.h),
                        OnboardingQuestion(
                          questionKey: uiConfigData?.aadhaarNumberQuestion ??
                              'aadhaar_details',
                          questionDefault:
                              uiConfigData?.aadhaarNumberQuestion ??
                                  'Aadhaar Details',
                          questionSubtitle: uiConfigData
                                  ?.aadharNumberQuestionSubtitle ??
                              "We will send an OTP to your Aadhaar-linked mobile number",
                          error: errorAadhaar,
                          questionTextStyle:
                              Theme.of(context).textTheme.headlineMedium,
                          questionSubtitleTextStyle: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(color: AppColors.n70),
                          padding: EdgeInsets.zero,
                          answer: TextFormField(
                            controller: aadhaarController,
                            keyboardType: TextInputType.number,
                            maxLength: 12,
                            decoration: InputDecoration(
                                border: const OutlineInputBorder(),
                                hintText: uiConfigData?.aadhaarNumberHint ??
                                    languageProvider.getMessage(
                                      'aadhaar_number_hint',
                                      'Enter your Aadhaar Card number',
                                    ),
                                hintStyle: AppTextTheme.hintStyle,
                                counter: const SizedBox()),
                          ),
                        ),
                        if (uiConfigData?.callOutData != null) ...[
                          OnboardingCallout(
                            callOut: uiConfigData?.callOutData,
                          ),
                          SizedBox(height: 28.h),
                        ],
                        if (navActions != null)
                          Column(
                            children: [
                              ...(navActions.actions.map((action) {
                                return ActionableText(
                                  statement: action.label ?? "",
                                  actionable: action.taskLabel ?? "",
                                  action: () {
                                    if (action.task == null) return;

                                    final sessionId =
                                        onboardingQuestionResponse?.sessionId;

                                    if (sessionId == null) return;

                                    final payload = {
                                      "session_id": sessionId,
                                      "action": action.task,
                                    };

                                    onboardingStepsProvider.performAction(
                                      context: context,
                                      data: payload,
                                      navigateOnSuccess: true,
                                    );
                                  },
                                );
                              }).toList()),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
    );
  }
}

class AadhaarDetailsUiConfig {
  final String? aadhaarNumberQuestion;
  final String? aadharNumberQuestionSubtitle;
  final String? aadhaarNumberRequiredMessage;
  final String? aadhaarNumberHint;
  final String? aadhaarNumberLoadingMessage;
  final CallOutData? callOutData;
  final NavActions? navActions;

  const AadhaarDetailsUiConfig({
    this.aadhaarNumberQuestion,
    this.aadharNumberQuestionSubtitle,
    this.aadhaarNumberRequiredMessage,
    this.aadhaarNumberHint,
    this.aadhaarNumberLoadingMessage,
    this.callOutData,
    this.navActions,
  });

  factory AadhaarDetailsUiConfig.fromJson(Map<String, dynamic> json) {
    return AadhaarDetailsUiConfig(
      aadhaarNumberQuestion: json['aadhaar_number_question'],
      aadharNumberQuestionSubtitle: json['aadhar_number_question_subtitle'],
      aadhaarNumberRequiredMessage: json['aadhaar_number_required_message'],
      aadhaarNumberHint: json['aadhaar_number_hint'],
      aadhaarNumberLoadingMessage: json['aadhaar_number_loading_message'],
      callOutData: json['callout'] != null
          ? CallOutData.fromJson(json['callout'])
          : null,
      navActions: json['nav_actions'] != null
          ? NavActions.fromJson(json['nav_actions'])
          : null,
    );
  }
}
