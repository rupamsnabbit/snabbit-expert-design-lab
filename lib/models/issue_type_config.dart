
import 'package:snabbit_runner/utils/common_methods.dart';

class IssueTypeConfig {
  final String? type;
  final bool? showTextField;
  final int? commentMinLength;

  /// Private constructor where all fields are optional (nullable).
  IssueTypeConfig({
    this.type,
    this.showTextField,
    this.commentMinLength,
  });

  /// Factory constructor to create an [IssueTypeConfig] instance from a JSON map.
  ///
  /// All fields are accessed safely and are nullable.
  factory IssueTypeConfig.fromJson(Map<String, dynamic> json) {
    return IssueTypeConfig(
      type: json['type'],
      showTextField: json['show_text_field'],
      commentMinLength: anyValueToInt(json['comment_min_length']),
    );
  }
}