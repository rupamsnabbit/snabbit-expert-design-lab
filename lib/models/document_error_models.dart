import 'package:flutter/material.dart';
import 'package:snabbit_runner/utils/common_methods.dart';

class CtaActions {
  CtaActions({
    this.label,
    this.backgroundColor,
    this.foregroundColor,
    this.task,
    this.link,
  });

  final String? label;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final String? task;
  final String? link;

  factory CtaActions.fromJson(Map<String, dynamic> json) {
    return CtaActions(
      label: json['label'],
      backgroundColor: _parseColor(json['background_color']),
      foregroundColor: _parseColor(json['foreground_color']),
      task: json['task_id'],
      link: json['link'],
    );
  }
}

class StatusInfo {
  StatusInfo({
    this.title,
    this.subtitle,
    this.icon,
    this.callOutData
  });

  final String? title;
  final String? subtitle;
  final String? icon;
  final CallOutData? callOutData;

  factory StatusInfo.fromJson(Map<String, dynamic>? json) {
    if (json == null) return StatusInfo();
    return StatusInfo(
      title: json['title'],
      subtitle: json['subtitle'],
      icon: json['icon'],
       callOutData: json['callout'] is Map
    ? CallOutData.fromJson(Map<String, dynamic>.from(json['callout']))
        : null,
    );
  }
}

class NextStep {
  NextStep({
    this.questionGroupKey,
    this.questionGroupId,
    this.reason,
    this.allowSkip,
    this.actions,
  });

  final String? questionGroupKey;
  final int? questionGroupId;
  final String? reason;
  final bool? allowSkip;
  final List<CtaActions>? actions;

  factory NextStep.fromJson(Map<String, dynamic>? json) {
    if (json == null) return NextStep();

    List<CtaActions>? parsedActions;
    final actionsJson = json['actions'];
    if (actionsJson is List) {
      parsedActions =
          actionsJson.map((element) => CtaActions.fromJson(element)).toList();
    }

    return NextStep(
      questionGroupKey: json['question_group_key']?.toString(),
      questionGroupId:
          int.tryParse(json['question_group_id']?.toString() ?? ''),
      reason: json['reason']?.toString(),
      allowSkip: json['allow_skip'],
      actions: parsedActions,
    );
  }
}

class OnboardingStatusData {
  OnboardingStatusData({
    this.pageType,
    this.sessionId,
    this.moduleId,
    this.totalNumberOfQuestion,
    this.currentQuestionNumber,
    this.status,
    this.nextStep,
  });

  final String? pageType;
  final int? sessionId;
  final int? moduleId;
  final int? totalNumberOfQuestion;
  final int? currentQuestionNumber;
  final StatusInfo? status;
  final NextStep? nextStep;

  factory OnboardingStatusData.fromJson(Map<String, dynamic> json) {
    return OnboardingStatusData(
      pageType: json['page_type'],
      sessionId: json['session_id'] is int
          ? json['session_id']
          : int.tryParse(json['session_id']?.toString() ?? ''),
      moduleId: json['module_id'] is int
          ? json['module_id']
          : int.tryParse(json['module_id']?.toString() ?? ''),
      totalNumberOfQuestion: json['total_number_of_question'] is int
          ? json['total_number_of_question']
          : int.tryParse(json['total_number_of_question']?.toString() ?? ''),
      currentQuestionNumber: json['current_question_number'] is int
          ? json['current_question_number']
          : int.tryParse(json['current_question_number']?.toString() ?? ''),
      status: json['status'] is Map
          ? StatusInfo.fromJson(Map<String, dynamic>.from(json['status']))
          : null,
      nextStep: json['next_step'] is Map
          ? NextStep.fromJson(Map<String, dynamic>.from(json['next_step']))
          : null,
    );
  }
}

class OnboardingFailedData {
  OnboardingFailedData({
    this.pageType,
    this.sessionId,
    this.moduleId,
    this.imageUrl,
    this.title,
    this.message,
    this.retryMessage,
  });

  final String? pageType;
  final int? sessionId;
  final int? moduleId;
  final String? imageUrl;
  final String? title;
  final String? message;
  final String? retryMessage;

  factory OnboardingFailedData.fromJson(Map<String, dynamic> json) {
    return OnboardingFailedData(
      pageType: json['page_type'],
      sessionId: anyValueToInt(json['session_id']),
      moduleId: anyValueToInt(json['module_id']),
      imageUrl: json['image_url'],
      title: json['title'],
      message: json['message'],
      retryMessage: json['retry_message'],
    );
  }
}

class CallOutData {
  CallOutData({
    this.description,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
  });

  final String? description;
  final String? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;

  factory CallOutData.fromJson(Map<String, dynamic> json) {
    return CallOutData(
        description: json['description'],
        icon: json['icon'],
        backgroundColor: _parseColor(json['background_color']),
        foregroundColor: _parseColor(json['foreground_color']),
        borderColor: _parseColor(json['border_color']));
  }
}

Color? _parseColor(dynamic value) {
  if (value == null) return null;
  if (value is Color) return value;
  if (value is int) return Color(value);
  if (value is String) {
    return hexToColor(value);
  }
  return null;
}
