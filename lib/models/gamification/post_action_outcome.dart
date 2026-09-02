import 'package:flutter/foundation.dart';
import 'package:snabbit_runner/models/gamification/gamification_constants.dart';
import 'package:snabbit_runner/models/gamification/nudge_label.dart';
import 'package:snabbit_runner/utils/common_methods.dart';

/// Post-action reward/penalty outcome — drives the popup + coin-flight animation
/// or the waiver bottom sheet.
class PostActionOutcome {
  final String lifecycleActionType;
  final String status; // OutcomeStatus.reward | .penalty | .waived
  final NudgeLabel label;
  final NudgeLabel? subtitleLabel;
  final int goldCoins; // delta for this action
  final int redCards; // delta for this action
  final int? goldCoinsTotal; // authoritative balance after this action
  final int? redCardsTotal; // authoritative balance after this action
  /// Title ribbon leading image (parallelogram bar). Optional — FE falls back
  /// to a solid dot if absent.
  final String? iconUrl;

  const PostActionOutcome({
    this.lifecycleActionType = '',
    required this.status,
    required this.label,
    this.subtitleLabel,
    this.goldCoins = 0,
    this.redCards = 0,
    this.goldCoinsTotal,
    this.redCardsTotal,
    this.iconUrl,
  });

  bool get isReward => goldCoins > 0;
  bool get isPenalty => redCards > 0;
  bool get isWaived => status.toLowerCase() == OutcomeStatus.waived;

  factory PostActionOutcome.fromMap(Map<String, dynamic> map) {
    final titleLabelRaw = map['titleLabel'] ?? map['title_label'];
    final subtitleLabelRaw = map['subtitleLabel'] ?? map['subtitle_label'];

    return PostActionOutcome(
      lifecycleActionType: map['lifecycleActionType']?.toString() ??
          map['lifecycle_action_type']?.toString() ??
          '',
      status: map['status']?.toString() ?? '',
      label: NudgeLabel.fromDynamic(
        titleLabelRaw,
        legacyTitle: map['title'] as String?,
      ),
      subtitleLabel: NudgeLabel.fromDynamic(
        subtitleLabelRaw,
        legacyTitle: map['subtitle'] as String?,
      ),
      goldCoins: anyValueToInt(map['goldCoins'] ?? map['gold_coins']) ?? 0,
      redCards: anyValueToInt(map['redCards'] ?? map['red_cards']) ?? 0,
      goldCoinsTotal:
          anyValueToInt(map['goldCoinsTotal'] ?? map['gold_coins_total']),
      redCardsTotal:
          anyValueToInt(map['redCardsTotal'] ?? map['red_cards_total']),
      iconUrl: _optionalStringUrl(map['iconUrl'] ?? map['icon_url']),
    );
  }

  static String? _optionalStringUrl(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return s;
  }

  static PostActionOutcome? tryFromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    try {
      final o = PostActionOutcome.fromMap(map);
      if (o.status.isEmpty) return null;
      return o;
    } catch (e, st) {
      debugPrint('[PostActionOutcome] parse error: $e\n$st');
      return null;
    }
  }
}
