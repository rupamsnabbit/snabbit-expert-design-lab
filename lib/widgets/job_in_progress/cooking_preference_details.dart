import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/utils/snake_case_localization_key.dart';

/// Row for `widget_data['cooking_preference']` on job-in-progress.
///
/// Each entry must be an object `{ "title": "...", "value": "..." }` under a
/// stable key (e.g. `oil_level`). Legacy flat string values are ignored.
///
/// Labels use [LanguageProvider.getMessage] with the **outer key** (e.g. `oil_level`)
/// and API `title` as default. Values use [snakeCaseLocalizationKey] on `value`
/// as the lookup key and API `value` as default.
typedef _CookingPrefRow = ({
  String prefKey,
  String titleDefault,
  String valueText,
});

class CookingPreferenceDetails extends StatelessWidget {
  final Map<String, dynamic>? widgetData;

  const CookingPreferenceDetails({
    super.key,
    required this.widgetData,
  });

  static String? _stringFrom(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final t = value.trim();
      return t.isEmpty ? null : t;
    }
    final s = value.toString().trim();
    return s.isEmpty ? null : s;
  }

  /// Sentence-case from snake_case key when API omits `title`.
  static String _formatPreferenceLabel(String raw) {
    final lowerSpaced = raw
        .split('_')
        .where((s) => s.isNotEmpty)
        .map((s) => s.toLowerCase())
        .join(' ');
    if (lowerSpaced.isEmpty) return raw;
    return '${lowerSpaced[0].toUpperCase()}${lowerSpaced.substring(1)}';
  }

  static List<_CookingPrefRow> _preferenceEntries(Map<dynamic, dynamic> raw) {
    final out = <_CookingPrefRow>[];
    for (final e in raw.entries) {
      final prefKey = e.key is String ? e.key as String : '${e.key}';
      final trimmedKey = prefKey.trim();
      if (trimmedKey.isEmpty) continue;
      final v = e.value;
      if (v is! Map) continue;
      final m = Map<String, dynamic>.from(v);
      final valueStr = _stringFrom(m['value']);
      if (valueStr == null) continue;
      final titleFromApi = _stringFrom(m['title']);
      final titleDefault =
          titleFromApi ?? _formatPreferenceLabel(trimmedKey);
      out.add((
        prefKey: trimmedKey,
        titleDefault: titleDefault,
        valueText: valueStr,
      ));
    }
    out.sort((a, b) => a.prefKey.compareTo(b.prefKey));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final raw = widgetData?['cooking_preference'];
    if (raw is! Map) {
      return const SizedBox.shrink();
    }
    final entries = _preferenceEntries(Map<dynamic, dynamic>.from(raw));
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, _) {
        final title = languageProvider.getMessage(
          'cooking_preference',
          'Cooking preference',
        );

        final labelStyle = TextStyle(
          fontSize: 13.sp,
          height: 16 / 13,
          fontWeight: FontWeight.w400,
          color: AppColors.n60,
        );
        final valueStyle = TextStyle(
          fontSize: 13.sp,
          height: 16 / 13,
          fontWeight: FontWeight.w600,
          color: AppColors.n80,
        );

        final wrapChildren = <Widget>[];
        for (var i = 0; i < entries.length; i++) {
          if (i > 0) {
            wrapChildren.add(
              Container(
                width: 1,
                height: 8.h,
                color: AppColors.n40,
              ),
            );
          }
          final entry = entries[i];
          final label = languageProvider.getMessage(
            entry.prefKey,
            entry.titleDefault,
          );
          final valueKey = snakeCaseLocalizationKey(entry.valueText);
          final displayValue = languageProvider.getMessage(
            valueKey.isNotEmpty ? valueKey : entry.valueText,
            entry.valueText,
          );
          wrapChildren.add(
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '$label: ', style: labelStyle),
                  TextSpan(text: displayValue, style: valueStyle),
                ],
              ),
            ),
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 24.w,
              height: 24.w,
              child: SvgPicture.asset(
                AssetConstants.cookingPreferenceIcon,
                width: 24.w,
                height: 24.w,
                fit: BoxFit.contain,
              ),
            ),
            SizedBox(width: 11.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12.sp,
                      height: 20 / 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.24,
                      color: AppColors.n90,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 9.w,
                    runSpacing: 4.h,
                    children: wrapChildren,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
