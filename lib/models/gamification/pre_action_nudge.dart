import 'package:flutter/foundation.dart';
import 'package:snabbit_runner/models/gamification/cta_override.dart';
import 'package:snabbit_runner/models/gamification/gamification_constants.dart';
import 'package:snabbit_runner/models/gamification/nudge_label.dart';
import 'package:snabbit_runner/utils/common_methods.dart';

class PreActionNudge {
  final String lifecycleActionType;
  final String nudgeKind;
  final String iconUrl;
  final NudgeLabel label;
  final int? goldCoins;
  final int? redCards;
  final DateTime? expiresAt;
  final List<CtaOverride>? ctaOverrides;

  const PreActionNudge({
    required this.lifecycleActionType,
    required this.nudgeKind,
    required this.iconUrl,
    required this.label,
    this.goldCoins,
    this.redCards,
    this.expiresAt,
    this.ctaOverrides,
  });

  bool get isOpportunity => nudgeKind == NudgeKind.opportunity;
  bool get isRisk => nudgeKind == NudgeKind.risk;
  /// Blue / brand highlight strip (e.g. OT bonus) — Figma Expert-App-2.0 `5510:27538`.
  bool get isBonus => nudgeKind == NudgeKind.bonus;
  bool get hasCountdown => expiresAt != null;
  bool get hasCtaOverrides =>
      ctaOverrides != null && ctaOverrides!.isNotEmpty;

  factory PreActionNudge.fromMap(Map<String, dynamic> map) {
    // BE sends camelCase (LLD) or snake_case (Python); canonical key is `icon_url`.
    final iconUrl = (map['iconUrl'] as String?) ??
        (map['icon_url'] as String?) ??
        '';
    final label = NudgeLabel.fromDynamic(
      map['label'],
      legacyTitle: map['title'] as String?,
    );
    final expiresRaw = map['expiresAt'] ?? map['expires_at'];
    return PreActionNudge(
      lifecycleActionType: map['lifecycleActionType']?.toString() ??
          map['lifecycle_action_type']?.toString() ??
          '',
      nudgeKind: map['nudgeKind']?.toString() ??
          map['nudge_kind']?.toString() ??
          '',
      iconUrl: iconUrl,
      label: label,
      goldCoins: anyValueToInt(map['goldCoins'] ?? map['gold_coins']),
      redCards: anyValueToInt(map['redCards'] ?? map['red_cards']),
      expiresAt: expiresRaw != null
          ? DateTime.tryParse(expiresRaw.toString())
          : null,
      ctaOverrides: CtaOverride.tryParseList(
        map['ctaOverrides'] ?? map['cta_overrides'],
      ),
    );
  }

  static PreActionNudge? tryFromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    try {
      final n = PreActionNudge.fromMap(map);
      if (n.lifecycleActionType.isEmpty ||
          n.nudgeKind.isEmpty ||
          n.iconUrl.isEmpty ||
          !n.label.isValid) {
        return null;
      }
      return n;
    } catch (e, st) {
      debugPrint('[PreActionNudge] parse error: $e\n$st');
      return null;
    }
  }
}

extension PreActionNudgeListX on List<PreActionNudge> {
  PreActionNudge? firstOfType(String type) =>
      where((n) => n.lifecycleActionType == type).firstOrNull;
}
