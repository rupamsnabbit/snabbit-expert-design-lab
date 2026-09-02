import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/models/document_error_models.dart';
import 'package:snabbit_runner/models/onboarding_question_data.dart';
import 'package:snabbit_runner/models/review/review_status_badge_config.dart';
import 'package:snabbit_runner/pages/signup/onboarding_progress_bar.dart';
import 'package:snabbit_runner/pages/signup/review/review_verification_status_badge.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/onboarding_steps_provider.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/enums.dart';
import 'package:snabbit_runner/utils/extensions/cdn_extensions.dart';
import 'package:snabbit_runner/widgets/onboarding_question.dart'
    show OnboardingPageHeaderV2;
import 'package:snabbit_runner/widgets/onboarding_question_v2.dart';
import 'package:snabbit_runner/widgets/overlapping_widget_setup.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';
import 'package:snabbit_runner/widgets/upload_documents/onboarding_callout.dart';
import 'package:snabbit_runner/widgets/upload_documents/onboarding_status_cta_buttons.dart';

class PersonalDetailsReviewV3 extends StatefulWidget {
  const PersonalDetailsReviewV3({super.key});

  static const String routeName = "/personal_details_review_v3";

  @override
  State<PersonalDetailsReviewV3> createState() =>
      _PersonalDetailsReviewV3State();
}

class _PersonalDetailsReviewV3State extends State<PersonalDetailsReviewV3> {
  final Map<String, dynamic> _modifiedAnswers = {};

  @override
  Widget build(BuildContext context) {
    final languageProvider = context.watch<LanguageProvider>();
    final onboardingStepsProvider = context.watch<OnboardingStepsProvider>();
    final response = onboardingStepsProvider.onboardingQuestionResponse;
    final questions = response?.questions ?? const <OnboardingQuestionData>[];
    final progressValue = _calculateProgress(response);

    final questionGroup = response?.onboardingQuestionGroup;
    final groupUiConfig = questionGroup?.uiConfig;
    final meta = groupUiConfig?.meta ?? const <String, dynamic>{};
    final callOut = _extractCallOut(meta);
    final ctaActions = _extractCtasFromResponse(response);
    final effectiveCtas = ctaActions;

    final items = questions
        .map(
          (question) => _ReviewQuestionItem.fromQuestion(
            question,
            languageProvider,
            _modifiedAnswers[question.id?.toString() ?? ''],
          ),
        )
        .toList();

    if (response == null) {
      return const Scaffold(
        body: Center(
          child: CupertinoActivityIndicator(),
        ),
      );
    }

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(elevation: 6),
        persistentFooterButtons: onboardingStepsProvider.loading
            ? null
            : [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: OnboardingStatusCtaButtons(
                    actions: effectiveCtas,
                    onActionTap: (task) => _handleCtaAction(
                        context, task, onboardingStepsProvider),
                  ),
                ),
              ],
        body: onboardingStepsProvider.loading
            ? Center(child: CupertinoActivityIndicator())
            : GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 6.h),
                      OnboardingProgressBar(progressValue: progressValue),
                      SizedBox(height: 33.h),
                      OnboardingPageHeaderV2(
                        title: groupUiConfig?.title ??
                            (questionGroup?.uiConfig?.title ??
                                'Review Personal Details'),
                        description: groupUiConfig?.description ??
                            'Please review and confirm your personal information.',
                        titleStyle: Theme.of(context).textTheme.headlineMedium,
                        subtitleStyle: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(color: AppColors.n70),
                      ),
                      if (callOut != null) ...[
                        SizedBox(height: 20.h),
                        OnboardingCallout(callOut: callOut),
                      ],
                      SizedBox(height: 24.h),
                      for (final item in items) ...[
                        OnboardingQuestionV2(
                          questionKey: item.questionKey ?? '',
                          questionDefault: item.questionDefault ?? '',
                          mandatory: item.mandatory,
                          qaGap: 0,
                          answer: _ReviewAnswerTile(
                            item: item,
                            onTextChanged: (value) {
                              setState(() {
                                _modifiedAnswers[item.questionId ?? ''] = value;
                              });
                            },
                          ),
                        ),
                        SizedBox(height: 16.h),
                      ],
                      SizedBox(height: 32.h),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  static double _calculateProgress(OnboardingQuestionResponse? response) {
    final total = response?.totalQuestions ?? 0;
    final currentIndex = response?.currentQuestionNumber ?? 0;
    if (total == 0) return 0;
    return currentIndex / total;
  }

  static CallOutData? _extractCallOut(Map<String, dynamic> meta) {
    final raw = meta['callOut'] ?? meta['call_out'];
    if (raw is Map) {
      return CallOutData.fromJson(Map<String, dynamic>.from(raw));
    }
    return null;
  }

  static List<CtaActions> _extractCtasFromResponse(
      OnboardingQuestionResponse? response) {
    if (response?.nextStep?.actions != null &&
        response!.nextStep!.actions!.isNotEmpty) {
      return response.nextStep!.actions!;
    }
    return const [];
  }

  void _handleCtaAction(
    BuildContext context,
    String? task,
    OnboardingStepsProvider stepsProvider,
  ) {
    if (task == null) return;

    final sessionId = stepsProvider.onboardingQuestionResponse?.sessionId;
    final questions = stepsProvider.onboardingQuestionResponse?.questions ?? [];

    if (sessionId == null) return;

    // Build responses array from all questions
    final responses = questions.map((question) {
      final questionId = question.id?.toString() ?? '';
      final modifiedAnswer = _modifiedAnswers[questionId];
      final previousResponse = question.previousResponse;
      final questionType = questionTypeToApiValue(question.questionType);

      final Map<String, dynamic> response = {
        "question_id": question.id,
        "question_type": questionType,
      };

      // Use modified answer if available, otherwise use previous response
      if (modifiedAnswer != null) {
        response["free_text_answer"] = modifiedAnswer.toString();
      } else if (previousResponse != null && previousResponse.isNotEmpty) {
        final prevResp = previousResponse.first;

        // Check if it's a text-based answer
        if (prevResp.freeTextAnswer != null &&
            prevResp.freeTextAnswer!.isNotEmpty) {
          response["free_text_answer"] = prevResp.freeTextAnswer;
        } else if (prevResp.optionId != null) {
          // Option-based answer
          response["option_ids"] = [prevResp.optionId];
        }
      }

      return response;
    }).toList();

    // Build the payload
    final payload = {
      "session_id": sessionId,
      "action": task,
      "responses": responses,
    };

    // Call performAction with the payload
    stepsProvider.performAction(
      context: context,
      data: payload,
      navigateOnSuccess: true,
      onError: (error) {
        if (context.mounted) {
          showSnackbar(context, error.title ?? 'An error occurred');
        }
      },
    );
  }
}

class _ReviewQuestionItem {
  _ReviewQuestionItem({
    this.questionKey,
    this.questionDefault,
    this.answer,
    this.mandatory,
    this.status,
    this.statusIconUrl,
    this.errorMessage,
    this.errorBackgroundColor,
    this.errorTextColor,
    this.errorBorderColor,
    this.errorIconUrl,
    this.calloutMessage,
    this.calloutBackgroundColor,
    this.calloutTextColor,
    this.calloutBorderColor,
    this.calloutIconUrl,
    this.calloutBottomPadding,
    this.bottomOverlap,
    this.questionId,
    this.questionType,
    this.modifiedAnswer,
  });

  final String? questionKey;
  final String? questionDefault;
  final String? answer;
  final bool? mandatory;
  final VerificationStatus? status;
  final String? statusIconUrl;
  final String? errorMessage;
  final Color? errorBackgroundColor;
  final Color? errorTextColor;
  final Color? errorBorderColor;
  final String? errorIconUrl;
  final String? calloutMessage;
  final Color? calloutBackgroundColor;
  final Color? calloutTextColor;
  final Color? calloutBorderColor;
  final String? calloutIconUrl;
  final double? calloutBottomPadding;
  final double? bottomOverlap;
  final String? questionId;
  final OnboardingQuestionType? questionType;
  final String? modifiedAnswer;

  factory _ReviewQuestionItem.fromQuestion(
    OnboardingQuestionData question,
    LanguageProvider languageProvider,
    dynamic modifiedAnswer,
  ) {
    final statusConfig = ReviewStatusBadgeConfig.tryParse(question.uiConfig);
    final status = statusConfig?.status ?? VerificationStatus.verified;

    final questionDefault = question.question ?? '';
    final questionKey =
        (question.uiConfig?['question_key'] as String?) ?? questionDefault;

    final answer = _resolveAnswer(question, languageProvider);

    final errorMessage = _localize(
      languageProvider,
      key: statusConfig?.errorMessageKey,
      fallback: statusConfig?.errorMessageDefault,
    );

    final uiConfig = question.uiConfig ?? {};
    final calloutSection = uiConfig['callout'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(uiConfig['callout'] as Map)
        : <String, dynamic>{};

    final calloutMessage = calloutSection['message'] ??
        uiConfig['callout_message'] ??
        uiConfig['item_callout'];

    final bottomOverlap = calloutSection['bottom_overlap'] != null
        ? (calloutSection['bottom_overlap'] as num).toDouble()
        : (uiConfig['bottom_overlap'] != null
            ? (uiConfig['bottom_overlap'] as num).toDouble()
            : 8.0); // Default overlap

    return _ReviewQuestionItem(
      questionKey: questionKey,
      questionDefault: questionDefault,
      answer: answer,
      mandatory: question.mandatory ?? false,
      status: status,
      statusIconUrl: statusConfig?.iconUrl,
      errorMessage: errorMessage,
      errorBackgroundColor: statusConfig?.errorBackgroundColor,
      errorTextColor: statusConfig?.errorTextColor,
      errorBorderColor: statusConfig?.errorBorderColor,
      errorIconUrl: statusConfig?.errorIconUrl,
      calloutMessage: calloutMessage?.toString(),
      calloutBackgroundColor: calloutSection['background_color'] != null
          ? _parseColor(calloutSection['background_color'])
          : const Color(0xffFFF8EC),
      calloutTextColor: calloutSection['text_color'] != null
          ? _parseColor(calloutSection['text_color'])
          : AppColors.y50,
      calloutBorderColor: calloutSection['border_color'] != null
          ? _parseColor(calloutSection['border_color'])
          : const Color(0xffF7D9A4),
      calloutIconUrl: calloutSection['icon']?.toString(),
      calloutBottomPadding: calloutSection['bottom_padding'] != null
          ? (calloutSection['bottom_padding'] as num).toDouble()
          : null,
      bottomOverlap: bottomOverlap,
      questionId: question.id?.toString(),
      questionType: question.questionType,
      modifiedAnswer: modifiedAnswer?.toString(),
    );
  }

  static String _resolveAnswer(
    OnboardingQuestionData question,
    LanguageProvider languageProvider,
  ) {
    final previous = question.previousResponse;
    final freeText = previous?.first.freeTextAnswer?.trim();
    if (freeText != null && freeText.isNotEmpty) {
      return freeText;
    }

    final optionId = previous?.first.optionId;
    final options = question.optionObjects ?? [];
    if (optionId != null) {
      final option = options.firstWhere(
        (opt) => opt.id == optionId,
        orElse: () => OnboardingQuestionOption(),
      );
      final optionLabel = option.text ?? option.value;
      if (optionLabel != null && optionLabel.isNotEmpty) {
        return languageProvider.getMessage(
          option.value ?? optionLabel.toLowerCase(),
          optionLabel,
        );
      }
    }

    return languageProvider.getMessage('not_available', 'Not available');
  }

  static String _localize(
    LanguageProvider languageProvider, {
    String? key,
    String? fallback,
  }) {
    if (key == null || key.trim().isEmpty) {
      return fallback ?? '';
    }
    return languageProvider.getMessage(key, fallback ?? '');
  }

  static Color? _parseColor(dynamic value) {
    try {
      if (value == null) return null;
      if (value is int) return Color(value);
      if (value is String) {
        if (value.startsWith('#')) {
          return Color(
              int.parse(value.substring(1, 7), radix: 16) + 0xFF000000);
        }
        return Color(int.parse(value, radix: 16) + 0xFF000000);
      }
    } catch (_) {
      // ignore malformed values
    }
    return null;
  }
}

class _ReviewAnswerTile extends StatefulWidget {
  const _ReviewAnswerTile({
    required this.item,
    this.onTextChanged,
  });

  final _ReviewQuestionItem item;
  final void Function(String)? onTextChanged;

  @override
  State<_ReviewAnswerTile> createState() => _ReviewAnswerTileState();
}

class _ReviewAnswerTileState extends State<_ReviewAnswerTile> {
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    final initialValue = widget.item.modifiedAnswer ?? widget.item.answer ?? '';
    _textController = TextEditingController(text: initialValue);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUnverified = widget.item.status == VerificationStatus.unverified;
    final isTextInput =
        widget.item.questionType == OnboardingQuestionType.textInput;
    final isEditable = isUnverified && isTextInput;

    final answerStyle = isUnverified
        ? Theme.of(context)
            .textTheme
            .headlineSmall
            ?.copyWith(color: AppColors.n70)
        : Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.n70,
            );

    final mainWidget = Container(
      padding: isUnverified ? EdgeInsets.all(16.r) : null,
      decoration: isUnverified
          ? BoxDecoration(
              border: Border.all(
                color: AppColors.n30, // Grey border
                width: 1.w,
              ),
              borderRadius: BorderRadius.circular(10.r),
              color: Colors.white)
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: isEditable
                ? TextField(
                    controller: _textController,
                    onChanged: widget.onTextChanged,
                    style: answerStyle,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      hintText: 'Enter value',
                      hintStyle: answerStyle?.copyWith(
                        color: AppColors.n50,
                      ),
                    ),
                  )
                : Text(
                    widget.item.answer ?? '',
                    style: answerStyle,
                  ),
          ),
          if (widget.item.status != null) ...[
            SizedBox(width: 16.w),
            ReviewVerificationStatusBadge(
              verificationStatus: widget.item.status!,
              statusImage: widget.item.statusIconUrl,
            ),
          ],
        ],
      ),
    );

    Widget? bottomWidget;
    if (isUnverified) {
      if (widget.item.calloutMessage?.isNotEmpty ?? false) {
        bottomWidget = _ReviewErrorMessage(
          message: widget.item.calloutMessage ?? '',
          backgroundColor: widget.item.calloutBackgroundColor,
          textColor: widget.item.calloutTextColor,
          borderColor: widget.item.calloutBorderColor,
          iconUrl: widget.item.calloutIconUrl,
          bottomPadding: widget.item.calloutBottomPadding,
        );
      } else if (widget.item.errorMessage?.isNotEmpty ?? false) {
        bottomWidget = _ReviewErrorMessage(
          message: widget.item.errorMessage ?? '',
          backgroundColor: widget.item.errorBackgroundColor,
          textColor: widget.item.errorTextColor,
          borderColor: widget.item.errorBorderColor,
          iconUrl: widget.item.errorIconUrl,
        );
      }
    }

    if (bottomWidget != null) {
      return OverlappingStackWidget(
        mainWidget: mainWidget,
        bottomWidget: bottomWidget,
        bottomOverlap: 16.h,
      );
    } else {
      return mainWidget;
    }
  }
}

class _ReviewErrorMessage extends StatelessWidget {
  const _ReviewErrorMessage({
    required this.message,
    this.backgroundColor,
    this.textColor,
    this.borderColor,
    this.iconUrl,
    this.bottomPadding,
  });

  final String message;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? borderColor;
  final String? iconUrl;
  final double? bottomPadding;

  @override
  Widget build(BuildContext context) {
    final effectiveBackground = backgroundColor ?? const Color(0xffFFF8EC);
    final effectiveBorder = borderColor ?? const Color(0xffF7D9A4);
    final effectiveTextColor = textColor ?? AppColors.y50;

    return Container(
      padding: EdgeInsets.only(
        top: 26.h,
        bottom: bottomPadding ?? 14.h,
        left: 16.w,
        right: 16.w,
      ),
      decoration: BoxDecoration(
        color: effectiveBackground,
        border: Border.all(color: effectiveBorder, width: 1.w),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (iconUrl?.isNotEmpty == true) ...[
            RemoteImageHandler(
              imageUrl: iconUrl?.cdn ?? '',
              width: 24.w,
              height: 24.w,
              fit: BoxFit.contain,
              errorWidget: const SizedBox(),
            ),
            SizedBox(width: 12.w),
          ],
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: effectiveTextColor,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
