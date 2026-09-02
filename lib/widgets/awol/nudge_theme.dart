import 'package:flutter/material.dart';
import '../../models/gamification/pre_action_nudge.dart';
import '../../utils/colors.dart';

/// Colour tokens for a pre-action nudge strip.
///
/// Mirrors Kotlin's `OverlayNudgeTheme` in `OverlayNudgeComponents.kt`.
/// Theming is driven by `nudgeKind` from the API: "risk" (default), "opportunity", "bonus".
class NudgeTheme {
  final Color bg;
  final Color border;
  final Color text;
  final Color badge;

  const NudgeTheme._({
    required this.bg,
    required this.border,
    required this.text,
    required this.badge,
  });

  static const NudgeTheme risk = NudgeTheme._(
    bg: AppColors.nudgeRiskBg,
    border: AppColors.nudgeRiskBorder,
    text: AppColors.nudgeRiskText,
    badge: AppColors.nudgeRiskBadge,
  );

  static const NudgeTheme opportunity = NudgeTheme._(
    bg: AppColors.nudgeOpportunityBg,
    border: AppColors.nudgeOpportunityBorder,
    text: AppColors.nudgeOpportunityText,
    badge: AppColors.nudgeOpportunityBadge,
  );

  static const NudgeTheme bonus = NudgeTheme._(
    bg: AppColors.nudgeBonusBg,
    border: AppColors.nudgeBonusBorder,
    text: AppColors.n0,
    badge: AppColors.nudgeBonusBadge,
  );

  static NudgeTheme forNudge(PreActionNudge? nudge) {
    if (nudge == null) return risk;
    if (nudge.isBonus) return bonus;
    if (nudge.isOpportunity) return opportunity;
    return risk;
  }
}
