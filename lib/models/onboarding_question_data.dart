import 'dart:convert';
import 'dart:ui';

import 'package:snabbit_runner/models/document_error_models.dart';
import 'package:snabbit_runner/providers/onboarding_steps_provider.dart';
import 'package:snabbit_runner/utils/common_methods.dart';

enum OnboardingQuestionType {
  languageSelection,
  singleSelect,
  multiSelect,
  yesOrNo,
  radioOptions,
  timeRangeSelector,
  horizontalMultiSelect,
  dateInput,
  phoneNumber,
  textInput;

  static OnboardingQuestionType? fromString(String? value) {
    if (value == null) return null;

    final normalized = value.trim().toUpperCase();

    switch (normalized) {
      case 'LANGUAGE_SELECTION':
        return OnboardingQuestionType.languageSelection;
      case 'SINGLE_SELECT':
        return OnboardingQuestionType.singleSelect;
      case 'MULTI_SELECT':
        return OnboardingQuestionType.multiSelect;
      case 'YES_OR_NO':
        return OnboardingQuestionType.yesOrNo;
      case 'RADIO_OPTIONS':
        return OnboardingQuestionType.radioOptions;
      case 'TIME_RANGE_SELECTOR':
        return OnboardingQuestionType.timeRangeSelector;
      case 'HORIZONTAL_MULTI_SELECT':
        return OnboardingQuestionType.horizontalMultiSelect;
      case 'DATE_INPUT':
        return OnboardingQuestionType.dateInput;
      case 'TEXT_INPUT':
        return OnboardingQuestionType.textInput;
      case 'PHONE_NUMBER':
        return OnboardingQuestionType.phoneNumber;
      default:
        return null;
    }
  }
}

class OnboardingQuestionResponse {
  final OnboardingPageType? pageType;
  final String? message;
  final int? sessionId;
  final int? moduleId;
  final bool? isLastGroup;
  final OnboardingQuestionGroup? onboardingQuestionGroup;
  final List<OnboardingQuestionData>? questions;
  final int? totalQuestions;
  final int? currentQuestionNumber;
  final NextStep? nextStep;

  OnboardingQuestionResponse({
    this.pageType,
    this.message,
    required this.sessionId,
    required this.moduleId,
    required this.isLastGroup,
    required this.onboardingQuestionGroup,
    required this.questions,
    this.currentQuestionNumber,
    this.totalQuestions,
    this.nextStep,
  });

  factory OnboardingQuestionResponse.fromJson(Map<String, dynamic> json) {
    return OnboardingQuestionResponse(
      pageType: OnboardingPageType.fromString(json['page_type']),
      message: json['message'],
      sessionId: json['session_id'],
      moduleId: json['module_id'],
      onboardingQuestionGroup: (() {
        final groupJson = json['next_question_group'] ?? json['question_group'];
        return groupJson != null
            ? OnboardingQuestionGroup.fromJson(groupJson)
            : null;
      })(),
      questions: (json['next_questions'] ?? json['questions'] ?? [])
          .map<OnboardingQuestionData>(
              (question) => OnboardingQuestionData.fromJson(question))
          .toList(),
      isLastGroup: json['is_last_group'],
      totalQuestions: json['total_number_of_question'],
      currentQuestionNumber: json['current_question_number'],
      nextStep: json['next_step'] != null
          ? NextStep.fromJson(json['next_step'])
          : null,
    );
  }
}

/// Represents a group (screen) of questions
class OnboardingQuestionGroup {
  final int? id;
  final String? name;
  final String? description;
  final int? sequenceId;
  final bool isActive;
  final DisplayMode? displayMode; // "single" or "multiple"
  final OnboardingQuestionGroupUIConfig? uiConfig;
  final OnboardingStepGroupKeys? groupKey;

  const OnboardingQuestionGroup({
    this.id,
    this.displayMode,
    this.uiConfig,
    this.groupKey,
    this.name,
    this.description,
    this.sequenceId,
    this.isActive = true,
  });

  factory OnboardingQuestionGroup.fromJson(Map<String, dynamic> json) {
    return OnboardingQuestionGroup(
      id: json['id'],
      displayMode: DisplayMode.fromString(json['display_mode']),
      name: json['name'],
      description: json['description'],
      sequenceId: json['sequence_id'],
      isActive: json['is_active'] ?? true,
      uiConfig: json['ui_config'] != null
          ? OnboardingQuestionGroupUIConfig.fromJson(
              _parseUiConfig(json['ui_config']))
          : null,
      groupKey: OnboardingStepGroupKeys.fromString(json['group_key']),
    );
  }

  static Map<String, dynamic> _parseUiConfig(dynamic uiConfig) {
    if (uiConfig is Map<String, dynamic>) {
      return uiConfig;
    } else if (uiConfig is String) {
      try {
        // Parse JSON string to Map
        return Map<String, dynamic>.from(jsonDecode(uiConfig));
      } catch (e) {
        return {};
      }
    }
    return {};
  }
}

class OnboardingQuestionOption {
  final int? id;
  final String? text;
  final String? value;
  final int? sequenceId;
  final int? score;
  final bool? isCorrect;
  final bool? isHardReject;

  // Only used for yes/no questions for now
  final OptionUIConfig? uiConfig;

  OnboardingQuestionOption({
    this.id,
    this.text,
    this.value,
    this.sequenceId,
    this.score,
    this.isCorrect,
    this.isHardReject,
    this.uiConfig,
  });

  factory OnboardingQuestionOption.fromJson(dynamic json) {
    // Handle both Map and String formats
    return OnboardingQuestionOption(
      id: json['id'],
      text: json['option_text'] ?? json['text'],
      value: json['option_value'],
      sequenceId: json['sequence_id'],
      score: json['score'],
      isCorrect: json['is_correct'],
      isHardReject: json['is_hard_reject'],
      uiConfig: json['ui_config'] != null
          ? OptionUIConfig.fromJson(json['ui_config'])
          : null,
    );
  }
}

class OnboardingQuestionData {
  final int? id;
  final String? question;
  final OnboardingQuestionType? questionType;
  final List<OnboardingQuestionOption>? optionObjects;
  final bool? isHardReject;
  final int? sequenceId;
  final Map<String, dynamic>? uiConfig;
  final bool? mandatory;
  final List<PreviousResponse>? previousResponse;

  OnboardingQuestionData({
    this.id,
    this.question,
    this.questionType,
    this.optionObjects,
    this.isHardReject,
    this.sequenceId,
    this.uiConfig,
    this.mandatory,
    this.previousResponse,
  });

  factory OnboardingQuestionData.fromJson(Map<String, dynamic> json) {
    final List<dynamic>? questions =
        json['next_questions'] ?? json['questions'];
    Map<String, dynamic>? firstQuestion;

    if (questions != null && questions.isNotEmpty) {
      firstQuestion = questions.first as Map<String, dynamic>;
    }

    final questionJson = firstQuestion ?? json;

    final List<dynamic>? optionsJson = questionJson['options'];

    final List<OnboardingQuestionOption>? optionObjects = optionsJson
        ?.map((e) => OnboardingQuestionOption.fromJson(e))
        .toList()
        .cast<OnboardingQuestionOption>();

    final previousResponseData = questionJson['responses'];
    List<PreviousResponse>? parsedResponses;
    if (previousResponseData != null) {
      if (previousResponseData is List) {
        parsedResponses = previousResponseData
            .map((r) => PreviousResponse.fromJson(r))
            .toList();
      } else if (previousResponseData is Map<String, dynamic>) {
        parsedResponses = [PreviousResponse.fromJson(previousResponseData)];
      }
    }

    return OnboardingQuestionData(
      id: questionJson['id'],
      question: questionJson['question'] ??
          questionJson['question_text'] ??
          questionJson['ui_config']?['question_text'] ??
          '',
      questionType: OnboardingQuestionType.fromString(
          questionJson['question_type'] ?? questionJson['type']),
      optionObjects: optionObjects,
      isHardReject: questionJson['is_hard_reject'],
      sequenceId: questionJson['sequence_id'],
      uiConfig: questionJson['ui_config'],
      mandatory: questionJson['mandatory'] ?? questionJson['is_required'],
      previousResponse: parsedResponses,
    );
  }
}

class PreviousResponse {
  final int? id;
  final String? freeTextAnswer;
  final int? optionId;
  final int? scoreAwarded;
  final bool? isHardReject;
  final DateTime? createdAt;

  PreviousResponse({
    this.id,
    this.freeTextAnswer,
    this.optionId,
    this.scoreAwarded,
    this.isHardReject,
    this.createdAt,
  });

  factory PreviousResponse.fromJson(Map<String, dynamic> json) {
    return PreviousResponse(
      id: json['id'],
      freeTextAnswer: json['free_text_answer'],
      optionId: json['option_id'],
      scoreAwarded: json['score_awarded'],
      isHardReject: json['is_hard_reject'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }
}

class OnboardingQuestionError {
  final String? imageUrl;
  final Map<String, dynamic>? message;

  OnboardingQuestionError({
    this.imageUrl,
    this.message,
  });

  factory OnboardingQuestionError.fromJson(Map<String, dynamic> json) {
    return OnboardingQuestionError(
      imageUrl: json['image_url'],
      message: json['message'],
    );
  }
}

class OnboardingQuestionGroupUIConfig {
  final String? imageUrl;
  final String? title;
  final String? description;
  final String? ctaText;
  final Color? ctaColor;
  final CallOutData? callOutData;
  final NavActions? navActions;
  final Map<String, dynamic>? meta;
  final Map<String, dynamic>? rawJson;

  OnboardingQuestionGroupUIConfig({
    this.imageUrl,
    this.title,
    this.description,
    this.ctaText,
    this.ctaColor,
    this.meta,
    this.callOutData,
    this.navActions,
    this.rawJson,
  });

  factory OnboardingQuestionGroupUIConfig.fromJson(Map<String, dynamic> json) {
    return OnboardingQuestionGroupUIConfig(
      imageUrl: json['image_url'],
      title: json['display_title'],
      description: json['display_description'],
      ctaText: json['cta_text'],
      ctaColor:
          json['cta_color'] != null ? hexToColor(json['cta_color']) : null,
      meta: json['meta'],
      callOutData: json['callout'] != null
          ? CallOutData.fromJson(json['callout'])
          : null,
      navActions: json['nav_actions'] != null
          ? NavActions.fromJson(json['nav_actions'])
          : null,
      rawJson: json,
    );
  }
}

class OptionUIConfig {
  final Color? ctaColor;
  final Color? foregroundColor;
  final String? ctaText;
  final String? ctaIcon;
  final String? subTitle;
  final String? trailingIcon;

  OptionUIConfig({
    this.ctaColor,
    this.foregroundColor,
    this.ctaIcon,
    this.ctaText,
    this.subTitle,
    this.trailingIcon,
  });

  factory OptionUIConfig.fromJson(Map<String, dynamic> json) {
    return OptionUIConfig(
      ctaColor:
          json['cta_color'] != null ? hexToColor(json['cta_color']) : null,
      foregroundColor: json['foreground_color'] != null
          ? hexToColor(json['foreground_color'])
          : null,
      ctaIcon: json['cta_icon'],
      ctaText: json['cta_text'],
      subTitle: json['subtitle'],
      trailingIcon: json['trailing_icon'],
    );
  }
}

Map<String, dynamic> buildAnswerRequest({
  required int sessionId,
  required List<OnboardingQuestionData> questions,
  Map<int, List<OnboardingQuestionOption>>?
      selectedOptionsMap, // questionId -> selected options
  Map<int, String>? userInputs, // questionId -> text/date input
}) {
  final List<Map<String, dynamic>> responses = questions.map((question) {
    final selectedOptions = selectedOptionsMap?[question.id] ?? [];
    final userInput = userInputs?[question.id];

    // Extract option IDs if present
    final List<int> optionIds = selectedOptions
        .where((opt) => opt.id != null)
        .map((opt) => opt.id!)
        .toList();

    final Map<String, dynamic> response = {
      "question_id": question.id,
      "question_type": questionTypeToApiValue(question.questionType),
    };

    switch (question.questionType) {
      // Options-based questions
      case OnboardingQuestionType.singleSelect:
      case OnboardingQuestionType.multiSelect:
      case OnboardingQuestionType.yesOrNo:
      case OnboardingQuestionType.radioOptions:
      case OnboardingQuestionType.languageSelection:
      case OnboardingQuestionType.horizontalMultiSelect:
        response["option_ids"] = optionIds;
        break;

      // Text/date/time input
      case OnboardingQuestionType.textInput:
      case OnboardingQuestionType.dateInput:
      case OnboardingQuestionType.timeRangeSelector:
      case OnboardingQuestionType.phoneNumber:
        response["free_text_answer"] = userInput ?? "";
        break;

      default:
        response["option_ids"] = optionIds;
    }

    return response;
  }).toList();

  return {
    "session_id": sessionId,
    "responses": responses,
  };
}

String questionTypeToApiValue(OnboardingQuestionType? type) {
  switch (type) {
    case OnboardingQuestionType.languageSelection:
      return "language_selection";
    case OnboardingQuestionType.singleSelect:
      return "single_select";
    case OnboardingQuestionType.multiSelect:
      return "multi_select";
    case OnboardingQuestionType.yesOrNo:
      return "yes_or_no";
    case OnboardingQuestionType.radioOptions:
      return "radio_options";
    case OnboardingQuestionType.timeRangeSelector:
      return "time_range_selector";
    case OnboardingQuestionType.horizontalMultiSelect:
      return "horizontal_multi_select";
    case OnboardingQuestionType.dateInput:
      return "date_input";
    case OnboardingQuestionType.textInput:
      return "text_input";
    case OnboardingQuestionType.phoneNumber:
      return "phone_number";
    default:
      return "unknown";
  }
}

class NavActions {
  final List<NavAction> actions;

  NavActions({required this.actions});

  factory NavActions.fromJson(List<dynamic> jsonList) {
    return NavActions(
      actions: jsonList.map((e) => NavAction.fromJson(e)).toList(),
    );
  }
}

class NavAction {
  final String? label;
  final String? task;
  final String? taskLabel;

  NavAction({
    this.label,
    this.task,
    this.taskLabel,
  });

  factory NavAction.fromJson(Map<String, dynamic> json) {
    return NavAction(
      label: json['label'],
      task: json['task'],
      taskLabel: json['task_label'],
    );
  }

  Map<String, dynamic> toJson() => {
        "label": label,
        "task": task,
        "task_label": taskLabel,
      };
}
