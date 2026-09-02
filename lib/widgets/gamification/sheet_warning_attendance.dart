import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:snabbit_runner/models/gamification/cta_override.dart';
import 'package:snabbit_runner/models/gamification/gamification_constants.dart';
import 'package:snabbit_runner/models/gamification/sheet_warning.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/services/gamification_manager.dart';
import 'package:snabbit_runner/widgets/gamification/cta_badge.dart';
import 'package:snabbit_runner/widgets/gamification/resolve_nudge_label.dart';

/// Convenience aliases so existing call sites don't need to change imports.
typedef AttendanceSheetLifecycle = LifecycleActionType;
typedef AttendanceSheetCtaIds = CtaId;

/// Rows matching [lifecycleActionType] (order preserved).
List<SheetWarning> filterSheetWarnings(
  List<SheetWarning> all,
  String lifecycleActionType,
) {
  return all
      .where((n) => n.lifecycleActionType == lifecycleActionType)
      .toList();
}

/// Per-[ctaId] map for sheet button labels and badges (last wins on duplicates).
Map<String, CtaOverride> ctaOverridesForSheet(List<SheetWarning> filtered) {
  return GamificationManager.instance.resolveCtaOverrides(filtered);
}

/// Resolves [CtaOverride.label] (NudgeLabel) when valid; otherwise i18n fallback.
String attendanceButtonLabelFromCta(
  CtaOverride? o,
  LanguageProvider lang,
  String fallbackKey,
  String fallbackEnglish,
) {
  final l = o?.label;
  if (l != null && l.isValid) {
    return resolveNudgeLabel(l, lang);
  }
  return lang.getMessage(fallbackKey, fallbackEnglish);
}

/// [ElevatedButton] child: text + optional [CtaBadgeChip] from gamification.
Widget attendanceSheetCtaButtonChild(
  BuildContext context, {
  required CtaOverride? cta,
  required LanguageProvider languageProvider,
  required String fallbackKey,
  required String fallbackEnglish,
  Color? foregroundColor,
}) {
  final label = attendanceButtonLabelFromCta(
    cta,
    languageProvider,
    fallbackKey,
    fallbackEnglish,
  );
  final style = Theme.of(context).textTheme.labelLarge?.copyWith(
        color: foregroundColor,
        fontWeight: FontWeight.w600,
      );
  final showBadge = cta != null && (cta.hasCoinBadge || cta.hasRedCardBadge);
  if (!showBadge) {
    return Text(label, style: style);
  }
  return Row(
    mainAxisSize: MainAxisSize.min,
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Text(label, style: style),
      SizedBox(width: 8.w),
      CtaBadgeChip(cta: cta),
    ],
  );
}
