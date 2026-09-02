import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/errors/custom_error.dart';
import 'package:snabbit_runner/models/onboarding_question_data.dart';
import 'package:snabbit_runner/pages/signup/onboarding_progress_bar.dart'
    show OnboardingProgressBar;
import 'package:snabbit_runner/providers/onboarding_steps_provider.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/widgets/onboarding_form_elements/date_input.dart';
import 'package:snabbit_runner/widgets/onboarding_form_elements/horizontal_multi_select.dart';
import 'package:snabbit_runner/widgets/onboarding_form_elements/radio_options_data.dart';
import 'package:snabbit_runner/widgets/onboarding_form_elements/text_input.dart';
import 'package:snabbit_runner/widgets/onboarding_form_elements/time_range_selector.dart';
import 'package:snabbit_runner/widgets/onboarding_question.dart';

class OnboardingMultipleQuestionsScreen extends StatefulWidget {
  static const String routeName = "/onboarding-multiple-questions-screen";

  const OnboardingMultipleQuestionsScreen({
    super.key,
  });

  @override
  State<OnboardingMultipleQuestionsScreen> createState() =>
      _OnboardingMultipleQuestionsScreenState();
}

class _OnboardingMultipleQuestionsScreenState
    extends State<OnboardingMultipleQuestionsScreen> {
  final Map<String, dynamic> _questionAnswers = {};
  late OnboardingStepsProvider onboardingStepsProvider;
  bool init = true;
  int? _selectedDurationHours;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      onboardingStepsProvider =
          Provider.of<OnboardingStepsProvider>(context, listen: true);

      // Prefill previously saved responses (each question has at most one response)
      final questions =
          onboardingStepsProvider.onboardingQuestionResponse?.questions ?? [];

      for (final question in questions) {
        final previousResponses = question.previousResponse;

        if (previousResponses == null || previousResponses.isEmpty) continue;
        final response = previousResponses.first;

        // Handle free text answers
        if (response.freeTextAnswer != null &&
            response.freeTextAnswer!.trim().isNotEmpty) {
          _questionAnswers[question.id?.toString() ?? ""] =
              response.freeTextAnswer;
          continue;
        }

        // Handle option-based answers
        final allOptions = question.optionObjects ?? [];
        final optionId = response.optionId;

        if (optionId != null) {
          final matchedOption = allOptions.firstWhere(
            (opt) => opt.id == optionId,
            orElse: () => OnboardingQuestionOption(),
          );

          if (matchedOption.id != null) {
            _questionAnswers[question.id?.toString() ?? ""] = matchedOption;
          }
        }
      }
    }
    super.didChangeDependencies();
  }

  OnboardingQuestionGroup? get currentQuestionGroup =>
      onboardingStepsProvider.currentQuestionsData;

  OnboardingQuestionResponse? get onboardingQuestionsResponse =>
      onboardingStepsProvider.onboardingQuestionResponse;

  OnboardingQuestionGroupUIConfig? get currentQuestionGroupUIConfig =>
      currentQuestionGroup?.uiConfig;

  bool get isHeightWeightInfoGroup =>
      currentQuestionGroup?.groupKey == 'height_and_weight_info';

  int? get sessionId => onboardingQuestionsResponse?.sessionId;

  int get _currentIndex =>
      onboardingQuestionsResponse?.currentQuestionNumber ?? 0;

  int get _totalSteps => onboardingQuestionsResponse?.totalQuestions ?? 0;

  double get _progressValue =>
      _totalSteps == 0 ? 0 : _currentIndex / _totalSteps;

  bool _hasHeaderContent() {
    final title = (currentQuestionGroup?.uiConfig?.title ?? "").trim();
    final subtitle = (currentQuestionGroup?.uiConfig?.description ?? "").trim();
    return title.isNotEmpty || subtitle.isNotEmpty;
  }

  bool get isLoading => init || onboardingStepsProvider.loading;

  bool _areAllMandatoryQuestionsAnswered() {
    final questions = onboardingQuestionsResponse?.questions ?? [];

    for (final question in questions) {
      if (question.mandatory == true) {
        final answer = _questionAnswers[question.id?.toString() ?? ""];
        if (answer == null ||
            (answer is String && answer.trim().isEmpty) ||
            (answer is List && answer.isEmpty)) {
          return false;
        }
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 6,
        leading: InkWell(
          onTap: () => onboardingStepsProvider.goBackToPreviousQuestion(
              context, onboardingQuestionsResponse!.moduleId!),
          child: const Icon(
            Icons.arrow_back_ios_rounded,
            color: AppColors.n80,
          ),
        ),
      ),
      persistentFooterButtons: isLoading
          ? null
          : [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.w),
                child: SizedBox(
                  width: 1.sw,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _areAllMandatoryQuestionsAnswered()
                            ? AppColors.brand
                            : AppColors.n60),
                    onPressed: _areAllMandatoryQuestionsAnswered()
                        ? () {
                            final questions =
                                onboardingQuestionsResponse?.questions ?? [];

                            if (sessionId == null || questions.isEmpty) return;

                            // Build the payload dynamically from all answers
                            final payload = {
                              "session_id": sessionId,
                              "responses": questions.map((question) {
                                final answer = _questionAnswers[
                                    question.id?.toString() ?? ""];
                                final questionType = questionTypeToApiValue(
                                    question.questionType);

                                final Map<String, dynamic> response = {
                                  "question_id": question.id,
                                  "question_type": questionType,
                                };

                                if (questionType == "text_input" ||
                                    questionType == "date_input" ||
                                    questionType == "time_range_selector" ||
                                    questionType == "phone_number") {
                                  response["free_text_answer"] =
                                      answer is String
                                          ? answer
                                          : answer?.toString() ?? "";
                                } else if (answer
                                    is List<OnboardingQuestionOption>) {
                                  response["option_ids"] = answer
                                      .where((opt) => opt.id != null)
                                      .map((opt) => opt.id!)
                                      .toList();
                                } else if (answer is OnboardingQuestionOption) {
                                  response["option_ids"] = [
                                    if (answer.id != null) answer.id!
                                  ];
                                } else if (answer is Map &&
                                    questionType == "time_range_selector") {
                                  response["answer_metadata"] = {
                                    "start_time": answer["start"],
                                    "end_time": answer["end"],
                                  };
                                }
                                return response;
                              }).toList(),
                            };

                            onboardingStepsProvider.submitAnswerAndProceed(
                              context: context,
                              data: payload,
                              onSuccess: () {},
                              onError: (CustomError error) {
                                showSnackbar(
                                    context,
                                    error.message ??
                                        error.title ??
                                        'Something went wrong');
                              },
                            );
                          }
                        : null,
                    child: Text(
                      currentQuestionGroupUIConfig?.ctaText ?? "Continue",
                    ),
                  ),
                ),
              ),
            ],
      body: isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    SizedBox(height: 6.h),
                    OnboardingProgressBar(progressValue: _progressValue),
                    SizedBox(height: 33.h),
                    if (_hasHeaderContent())
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          OnboardingPageHeaderV2(
                            title: currentQuestionGroup?.uiConfig?.title,
                            description:
                                currentQuestionGroup?.uiConfig?.description,
                            titleStyle:
                                Theme.of(context).textTheme.headlineMedium,
                            subtitleStyle: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(color: AppColors.n70),
                          ),
                          if (currentQuestionGroup?.uiConfig?.title != null ||
                              currentQuestionGroup?.uiConfig?.description !=
                                  null)
                            SizedBox(height: 28.h),
                        ],
                      ),
                    ...(onboardingQuestionsResponse?.questions ?? [])
                        .map((question) {
                      Widget questionWidget;

                      if (question.questionType ==
                          OnboardingQuestionType.textInput) {
                        questionWidget = TextInput(
                          data: question,
                          onChanged: (value) {
                            _questionAnswers[question.id?.toString() ?? ""] =
                                value;
                            setState(() {});
                          },
                          initialValue:
                              (question.previousResponse?.isNotEmpty ?? false)
                                  ? question
                                      .previousResponse!.first.freeTextAnswer
                                  : null,
                        );
                      } else if (question.questionType ==
                          OnboardingQuestionType.phoneNumber) {
                        questionWidget = TextInput(
                          data: question,
                          initialValue:
                              (question.previousResponse?.isNotEmpty ?? false)
                                  ? question
                                      .previousResponse!.first.freeTextAnswer
                                  : null,
                          onChanged: (value) {
                            _questionAnswers[question.id?.toString() ?? ""] =
                                value;
                            setState(() {});
                          },
                        );
                      } else if (question.questionType ==
                          OnboardingQuestionType.dateInput) {
                        questionWidget = DateInput(
                          data: question,
                          initialValue:
                              (question.previousResponse?.isNotEmpty ?? false)
                                  ? question
                                      .previousResponse!.first.freeTextAnswer
                                  : null,
                          onSelected: (selectedDate) {
                            _questionAnswers[question.id?.toString() ?? ""] =
                                selectedDate;
                            setState(() {});
                          },
                        );
                      } else if (question.questionType ==
                          OnboardingQuestionType.timeRangeSelector) {
                        // Use the previously saved value directly (e.g. "10:30-18:00" or "09:00")
                        final initialValue =
                            (question.previousResponse?.isNotEmpty ?? false)
                                ? question
                                    .previousResponse!.first.freeTextAnswer
                                : null;

                        questionWidget = TimeRangeSelector(
                          data: question,
                          initialValue: initialValue,
                          selectedDurationInHours: _selectedDurationHours,
                          onChanged: (start, end) {
                            // Helper to format null-safe time strings
                            String? formatTime(String? time) {
                              if (time == null || time.isEmpty) return null;
                              final parts = time.split(':');
                              if (parts.length != 2) return null;
                              final hour = parts[0].padLeft(2, '0');
                              final minute = parts[1].padLeft(2, '0');
                              return '$hour:$minute';
                            }

                            final startTime = formatTime(start);
                            final endTime = formatTime(end);

                            // Combine into a single string (like freeTextAnswer)
                            String? value;
                            if (startTime != null && endTime != null) {
                              value = '$startTime-$endTime';
                            } else if (startTime != null) {
                              value = startTime;
                            } else {
                              value = null;
                            }

                            _questionAnswers[question.id?.toString() ?? ""] =
                                value;
                            setState(() {});
                          },
                        );
                      } else if (question.questionType ==
                          OnboardingQuestionType.radioOptions) {
                        questionWidget = RadioOptions(
                          data: question,
                          initialOptionId:
                              question.previousResponse?.first.optionId,
                          onSelected: (selectedOption) {
                            _questionAnswers[question.id?.toString() ?? ""] =
                                selectedOption;
                            setState(() {});
                          },
                        );
                      } else if (question.questionType ==
                          OnboardingQuestionType.horizontalMultiSelect) {
                        questionWidget = HorizontalMultiSelect(
                          data: question,
                          initialOptionId:
                              question.previousResponse?.first.optionId,
                          onSelected: (selectedOption) {
                            _questionAnswers[question.id?.toString() ?? ""] =
                                selectedOption;

                            // Only set duration if there's a time range selector that has auto_calculate_end_time enabled
                            final hasAutoCalculateTimeSelector =
                                onboardingQuestionsResponse?.questions?.any(
                                        (q) =>
                                            q.questionType ==
                                                OnboardingQuestionType
                                                    .timeRangeSelector &&
                                            q.uiConfig?[
                                                    'auto_calculate_end_time'] ==
                                                true) ??
                                    false;

                            if (hasAutoCalculateTimeSelector &&
                                selectedOption is OnboardingQuestionOption &&
                                selectedOption.text != null) {
                              _selectedDurationHours =
                                  anyValueToInt(selectedOption.text!);
                            } else {
                              _selectedDurationHours = null;
                            }

                            setState(() {});
                          },
                        );
                      } else {
                        questionWidget = const SizedBox.shrink();
                      }
                      // Add vertical spacing after each question
                      return Padding(
                        padding: EdgeInsets.only(bottom: 20.h),
                        child: questionWidget,
                      );
                    }),
                  ],
                ),
              ),
            ),
    );
  }
}
