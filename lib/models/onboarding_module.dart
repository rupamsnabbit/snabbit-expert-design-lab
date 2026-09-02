import 'dart:ui';

import 'package:snabbit_runner/utils/common_methods.dart';

class ModuleGroupResponse {
  final int currentModuleGroupId;
  final String currentModuleName;
  final String currentModuleDescription;
  final ModuleGroupUiConfig currentModuleUiConfig;
  final List<Module> modules;
  final bool? enableGoLive;
  final int progress;
  final int totalModules;
  final int completedCount;

  ModuleGroupResponse({
    required this.currentModuleGroupId,
    required this.currentModuleName,
    required this.currentModuleDescription,
    required this.currentModuleUiConfig,
    required this.modules,
    required this.progress,
    required this.totalModules,
    required this.completedCount,
    this.enableGoLive,
  });

  factory ModuleGroupResponse.fromJson(Map<String, dynamic> json) {
    return ModuleGroupResponse(
      currentModuleGroupId: json['current_module_group_id'] ?? 0,
      currentModuleName: json['current_module_name'] ?? '',
      currentModuleDescription: json['current_module_description'] ?? '',
      currentModuleUiConfig:
          ModuleGroupUiConfig.fromJson(json['current_module_ui_config'] ?? {}),
      modules: (json['modules'] as List<dynamic>? ?? [])
          .map((e) => Module.fromJson(e))
          .toList(),
      progress: json['progress'] ?? 0,
      totalModules: json['total_modules'] ?? 0,
      completedCount: json['completed_count'] ?? 0,
      enableGoLive: json['enable_go_live'],
    );
  }
}

class ModuleGroupUiConfig {
  final String? imageUrl;
  final String? languageIcon;
  final String? subtitle;
  final String? title;

  ModuleGroupUiConfig({
    this.imageUrl,
    this.subtitle,
    this.title,
    this.languageIcon,
  });

  factory ModuleGroupUiConfig.fromJson(Map<String, dynamic> json) {
    return ModuleGroupUiConfig(
      imageUrl: json['image_url'],
      languageIcon: json['language_icon'],
      subtitle: json['subtitle'],
      title: json['title'],
    );
  }
}

class Module {
  final int id;
  final String name;
  final String moduleKey;
  final String description;
  final StepStatus stepStatus;
  final ModuleUiConfig uiConfig;

  Module({
    required this.id,
    required this.name,
    required this.moduleKey,
    required this.description,
    required this.stepStatus,
    required this.uiConfig,
  });

  factory Module.fromJson(Map<String, dynamic> json) {
    return Module(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      moduleKey: json['module_key'] ?? '',
      description: json['description'] ?? '',
      stepStatus: StepStatusExtension.fromString(json['status']),
      uiConfig: ModuleUiConfig.fromJson(json['ui_config'] ?? {}),
    );
  }
}

class ModuleUiConfig {
  final Color? ctaColor;
  final Color? ctaTextColor;
  final Color? borderColor;
  final String? moduleIcon;
  final String? moduleImage;
  final String? ctaText;

  ModuleUiConfig({
    this.ctaColor,
    this.ctaTextColor,
    this.borderColor,
    this.moduleIcon,
    this.moduleImage,
    this.ctaText,
  });

  factory ModuleUiConfig.fromJson(Map<String, dynamic> json) {
    return ModuleUiConfig(
      ctaColor:
          json['cta_color'] != null ? hexToColor(json['cta_color']) : null,
      ctaTextColor: json['cta_text_color'] != null
          ? hexToColor(json['cta_text_color'])
          : null,
      borderColor: json['border_color'] != null
          ? hexToColor(json['border_color'])
          : null,
      moduleIcon: json['module_icon'],
      moduleImage: json['module_image'],
      ctaText: json['cta_text'],
    );
  }
}

enum StepStatus {
  pending,
  created,
  inProgress,
  completed,
}

extension StepStatusExtension on StepStatus {
  static StepStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'pending':
        return StepStatus.pending;
      case 'created':
        return StepStatus.created;
      case 'inprogress':
        return StepStatus.inProgress;
      case 'completed':
        return StepStatus.completed;
      default:
        return StepStatus.pending;
    }
  }
}
