import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/consent_text_data.dart';
import 'package:snabbit_runner/models/errors/custom_error.dart';
import 'package:snabbit_runner/widgets/pdf_view.dart';
import 'package:snabbit_runner/models/onboarding_question_data.dart';
import 'package:snabbit_runner/pages/signup/onboarding_progress_bar.dart';
import 'package:snabbit_runner/pages/signup/pan_number_updater.dart';
import 'package:snabbit_runner/providers/credentials_management_provider.dart';
import 'package:snabbit_runner/providers/onboarding_steps_provider.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/extensions/cdn_extensions.dart';
import 'package:snabbit_runner/widgets/onboarding_form_elements/radio_list_tile.dart';
import 'package:snabbit_runner/widgets/onboarding_question.dart';
import 'package:snabbit_runner/widgets/upload_documents/onboarding_callout.dart';

enum AadhaarUploadOptions {
  photos,
  number,
}

class AadhaarDetails extends StatefulWidget {
  static const String routeName = "/aadhaar-details";

  const AadhaarDetails({super.key});

  @override
  State<AadhaarDetails> createState() => _AadhaarDetailsState();
}

class _AadhaarDetailsState extends State<AadhaarDetails> {
  late OnboardingStepsProvider onboardingStepsProvider;
  OnboardingQuestionOption? selectedOption;
  bool consentGiven = false;

  bool init = true;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      onboardingStepsProvider =
          Provider.of<OnboardingStepsProvider>(context, listen: true);
      _handlePreviousResponse();

      setState(() {});
    }
    super.didChangeDependencies();
  }

  void _handlePreviousResponse() {
    if (questions.isEmpty) return;

    final currentQuestion = questions.first;
    final previousResponses = currentQuestion.previousResponse ?? [];
    final allOptions = currentQuestion.optionObjects ?? [];

    if (previousResponses.isNotEmpty && allOptions.isNotEmpty) {
      final previousOptionIds = previousResponses
          .where((r) => r.optionId != null)
          .map((r) => r.optionId!)
          .toSet();

      final matchedOptions = allOptions
          .where((option) => previousOptionIds.contains(option.id))
          .toList();

      if (matchedOptions.isNotEmpty) {
        selectedOption = matchedOptions.first;
      }
    }

    // Handle previous consent response
    final consent = consentQuestion;
    if (consent != null) {
      final consentPreviousResponses = consent.previousResponse ?? [];
      if (consentPreviousResponses.isNotEmpty) {
        final consentOptions = consent.optionObjects ?? [];
        final previousConsentOptionIds = consentPreviousResponses
            .where((r) => r.optionId != null)
            .map((r) => r.optionId!)
            .toSet();

        // Check if user previously selected "Yes"
        final yesOption = consentOptions.firstWhere(
          (option) =>
              option.text?.toLowerCase() == 'yes' ||
              option.value?.toLowerCase() == 'yes',
          orElse: () => consentOptions.first,
        );

        if (previousConsentOptionIds.contains(yesOption.id)) {
          consentGiven = true;
        }
      }
    }
  }

  OnboardingQuestionResponse? get onboardingQuestionResponse =>
      onboardingStepsProvider.onboardingQuestionResponse;
  OnboardingQuestionGroup? get onboardingQuestionGroupGroup =>
      onboardingStepsProvider.currentQuestionsData;

  OnboardingQuestionGroupUIConfig? get onboardingQuestionGroupUiConfig =>
      onboardingQuestionGroupGroup?.uiConfig;

  List<OnboardingQuestionData> get questions =>
      onboardingQuestionResponse?.questions ?? [];

  int? get sessionId => onboardingQuestionResponse?.sessionId;

  int get _currentIndex =>
      onboardingQuestionResponse?.currentQuestionNumber ?? 0;

  int get _totalSteps => onboardingQuestionResponse?.totalQuestions ?? 0;

  double get _progressValue =>
      _totalSteps == 0 ? 0 : _currentIndex / _totalSteps;

  OnboardingQuestionData? get consentQuestion => questions.length > 1 &&
          questions[1].questionType == OnboardingQuestionType.yesOrNo
      ? questions[1]
      : null;

  void _submitAnswer() {
    if (questions.isEmpty || selectedOption == null || sessionId == null) {
      return;
    }

    try {
      final currentQuestion = questions.first;
      final consent = consentQuestion;
      List<OnboardingQuestionData> tempQuestions = [];
      Map<int, List<OnboardingQuestionOption>> selectedOptionsMap = {};

      tempQuestions.add(currentQuestion);
      selectedOptionsMap[currentQuestion.id!] = [selectedOption!];

      // Add consent response if consent question exists and consent is given
      if (consent != null && consentGiven) {
        tempQuestions.add(consent);
        // Find the "Yes" option from consent question
        final yesOption = consent.optionObjects?.firstWhere(
          (option) =>
              option.text?.toLowerCase() == 'yes' ||
              option.value?.toLowerCase() == 'yes',
          orElse: () => consent.optionObjects!.first,
        );
        if (yesOption != null) {
          selectedOptionsMap[consent.id!] = [yesOption];
        }
      }

      final payload = buildAnswerRequest(
        sessionId: sessionId!,
        questions: tempQuestions,
        selectedOptionsMap: selectedOptionsMap,
      );

      onboardingStepsProvider.submitAnswerAndProceed(
        context: context,
        data: payload,
        onSuccess: () {
          setState(() {
            selectedOption = null;
            consentGiven = false;
          });
        },
        onError: (CustomError error) {
          showSnackbar(
              context, error.message ?? error.title ?? 'Something went wrong');
        },
      );
    } catch (e) {
      //
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isLoading = init || onboardingStepsProvider.loading;

    NavActions? navActions = onboardingQuestionGroupUiConfig?.navActions;

    return Scaffold(
      appBar: AppBar(
        elevation: 6,
        leading: InkWell(
          onTap: isLoading
              ? null
              : () => onboardingStepsProvider.goBackToPreviousQuestion(
                  context, onboardingQuestionResponse!.moduleId!),
          child: isLoading
              ? null
              : const Icon(
                  Icons.arrow_back_ios_rounded,
                  color: AppColors.n80,
                ),
        ),
      ),
      persistentFooterButtons: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.w),
          child: SizedBox(
            width: 1.sw,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: onboardingQuestionGroupUiConfig?.ctaColor ??
                      AppColors.brand),
              onPressed: isLoading ||
                      selectedOption == null ||
                      (consentQuestion != null && !consentGiven)
                  ? null
                  : () => _submitAnswer(),
              child: Text(
                onboardingQuestionGroupUiConfig?.ctaText ?? "Continue",
              ),
            ),
          ),
        ),
      ],
      body: isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 6.h),
                  OnboardingProgressBar(progressValue: _progressValue),
                  SizedBox(height: 33.h),
                  OnboardingPageHeaderV2(
                    title: onboardingQuestionGroupUiConfig?.title ??
                        "Aadhaar Details",
                    description: onboardingQuestionGroupUiConfig?.description ??
                        "Choose one method to verify your Aadhaar card to continue",
                    titleStyle: Theme.of(context).textTheme.headlineMedium,
                    subtitleStyle: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(color: AppColors.n70),
                  ),
                  SizedBox(height: 28.h),
                  ...(questions.isNotEmpty
                          ? questions.first.optionObjects ?? []
                          : [])
                      .map(
                    (option) => Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      child: Column(
                        children: [
                          RadioListTileQuestion(
                            option: option,
                            selectedOption: selectedOption,
                            onTap: (selected) =>
                                setState(() => selectedOption = selected),
                          ),
                          SizedBox(height: 12.h),
                        ],
                      ),
                    ),
                  ),
                  if (onboardingQuestionGroupUiConfig?.callOutData != null) ...[
                    OnboardingCallout(
                      callOut: onboardingQuestionGroupUiConfig?.callOutData,
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
                            padding: EdgeInsets.symmetric(horizontal: 16.w),
                          );
                        }).toList()),
                      ],
                    ),
                  if (consentQuestion != null)
                    Container(
                      color: AppColors.n0,
                      padding:
                          EdgeInsets.symmetric(horizontal: 0.w, vertical: 12.h),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Theme(
                            data: ThemeData(
                              checkboxTheme: CheckboxThemeData(
                                fillColor: WidgetStateProperty.resolveWith(
                                  (states) {
                                    if (states.contains(WidgetState.selected)) {
                                      return AppColors.brand;
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ),
                            child: Checkbox(
                              value: consentGiven,
                              onChanged: (value) {
                                setState(() {
                                  consentGiven = value ?? false;
                                });
                              },
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  consentGiven = !consentGiven;
                                });
                              },
                              child: _ConsentText(
                                consentTextData:
                                    ConsentTextData.fromQuestionData(
                                        consentQuestion!),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _ConsentText extends StatelessWidget {
  final ConsentTextData consentTextData;

  const _ConsentText({required this.consentTextData});

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontSize: 15.sp,
          height: 1.4,
        );

    final linkStyle = textStyle?.copyWith(
      color: AppColors.brand,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.brand,
      decorationThickness: 2.0,
      fontWeight: FontWeight.w600,
    );

    return RichText(
      text: TextSpan(
        style: textStyle,
        children: [
          TextSpan(text: consentTextData.question),
          if (consentTextData.text.isNotEmpty) ...[
            TextSpan(text: ' '),
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: GestureDetector(
                onTap: consentTextData.url.isEmpty
                    ? null
                    : () {
                        // Open PDF in in-app viewer
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                PdfViewPage(url: consentTextData.url.cdn),
                          ),
                        );
                      },
                child: Text(
                  consentTextData.text,
                  style: linkStyle,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
