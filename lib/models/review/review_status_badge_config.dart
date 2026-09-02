import 'package:flutter/material.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/enums.dart';

class ReviewStatusBadgeConfig {
  ReviewStatusBadgeConfig({
    this.status,
    this.labelKey,
    this.labelDefault,
    this.iconUrl,
    this.backgroundColor,
    this.textColor,
    this.borderColor,
    this.errorMessageKey,
    this.errorMessageDefault,
    this.errorBackgroundColor,
    this.errorTextColor,
    this.errorBorderColor,
    this.errorIconUrl,
  });

  final VerificationStatus? status;
  final String? labelKey;
  final String? labelDefault;
  final String? iconUrl;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? borderColor;
  final String? errorMessageKey;
  final String? errorMessageDefault;
  final Color? errorBackgroundColor;
  final Color? errorTextColor;
  final Color? errorBorderColor;
  final String? errorIconUrl;

  bool get hasErrorMessage =>
      (errorMessageKey ?? '').trim().isNotEmpty ||
      (errorMessageDefault ?? '').trim().isNotEmpty;

  static ReviewStatusBadgeConfig? tryParse(Map<String, dynamic>? source) {
    if (source == null || source.isEmpty) return null;

    Map<String, dynamic> badgeJson = Map<String, dynamic>.from(source);
    const candidateKeys = [
      'status_badge',
      'review_status',
      'verification_status',
      'status_config',
    ];

    for (final key in candidateKeys) {
      final value = source[key];
      if (value is Map<String, dynamic>) {
        badgeJson = Map<String, dynamic>.from(value);
        break;
      }
    }

    final errorSection = badgeJson['error'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(badgeJson['error'] as Map)
        : <String, dynamic>{};

    return ReviewStatusBadgeConfig(
      status: VerificationStatus.fromString(
        badgeJson['status'],
      ),
      labelKey: badgeJson['label_key'],
      labelDefault: badgeJson['label_default'] ?? badgeJson['label'],
      iconUrl: badgeJson['status_icon'] ?? badgeJson['icon_url'],
      backgroundColor: _parseColor(
        badgeJson['background_color'],
      ),
      textColor: _parseColor(
        badgeJson['text_color'],
      ),
      borderColor: _parseColor(
        badgeJson['border_color'],
      ),
      errorMessageKey: badgeJson['error_message_key'],
      errorMessageDefault: errorSection['message_default'] ??
          errorSection['message'] ??
          badgeJson['error_message_default'] ??
          badgeJson['error_message'],
      errorBackgroundColor: _parseColor(
            errorSection['background_color'],
          ) ??
          _parseColor(
            badgeJson['error_background_color'],
          ),
      errorTextColor: _parseColor(
            errorSection['text_color'],
          ) ??
          _parseColor(
            badgeJson['error_text_color'],
          ),
      errorBorderColor: _parseColor(
            errorSection['border_color'],
          ) ??
          _parseColor(
            badgeJson['error_border_color'],
          ),
      errorIconUrl: errorSection['icon'] ?? badgeJson['error_icon'],
    );
  }
}

Color? _parseColor(dynamic value) {
  try {
    if (value == null) return null;
    if (value is int) return Color(value);
    if (value is String) return hexToColor(value);
  } catch (_) {
    // ignore malformed values
  }
  return null;
}
