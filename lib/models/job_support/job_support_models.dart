import 'package:snabbit_runner/models/awol/awol_models.dart';

class JobSupportOption {
  final String id;
  final TranslatableText label;
  final String? iconUrl;

  JobSupportOption({
    required this.id,
    required this.label,
    this.iconUrl,
  });

  factory JobSupportOption.fromJson(Map<String, dynamic> json) {
    return JobSupportOption(
      id: json['id']?.toString() ?? '',
      label: json['label'] is Map<String, dynamic>
          ? TranslatableText.fromJson(json['label'])
          : TranslatableText(key: '', defaultText: json['label']?.toString() ?? ''),
      iconUrl: json['icon_url']?.toString(),
    );
  }
}

class JobSupportConfig {
  final List<JobSupportOption> options;

  JobSupportConfig({required this.options});

  factory JobSupportConfig.fromJson(Map<String, dynamic> json) {
    final optionsList = json['options'];
    return JobSupportConfig(
      options: optionsList is List
          ? optionsList
              .whereType<Map<String, dynamic>>()
              .map(JobSupportOption.fromJson)
              .where((o) => o.id.isNotEmpty)
              .toList()
          : [],
    );
  }
}
