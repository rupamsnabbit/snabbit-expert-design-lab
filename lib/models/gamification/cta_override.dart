import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:snabbit_runner/models/gamification/nudge_label.dart';
import 'package:snabbit_runner/utils/common_methods.dart';

class CtaOverride {
  final String ctaId;
  final NudgeLabel? label;
  final int? goldCoins;
  final int? redCards;

  const CtaOverride({
    required this.ctaId,
    this.label,
    this.goldCoins,
    this.redCards,
  });

  bool get hasCoinBadge => goldCoins != null && goldCoins! > 0;
  bool get hasRedCardBadge => redCards != null && redCards! > 0;

  static CtaOverride? tryFromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    try {
      final idRaw = map['ctaId'] ?? map['cta_id'];
      final id = idRaw is String
          ? idRaw
          : (idRaw != null ? idRaw.toString().trim() : null);
      if (id == null || id.isEmpty) return null;
      final parsedLabel = NudgeLabel.fromDynamic(map['label']);
      return CtaOverride(
        ctaId: id,
        label: parsedLabel.isValid ? parsedLabel : null,
        goldCoins: anyValueToInt(map['goldCoins'] ?? map['gold_coins']),
        redCards: anyValueToInt(map['redCards'] ?? map['red_cards']),
      );
    } catch (e, st) {
      FirebaseCrashlytics.instance.recordError(
        e, st,
        reason: 'CtaOverride.tryFromMap',
        fatal: false,
      );
      return null;
    }
  }

  /// Parses `ctaOverrides` JSON the same way as [PreActionNudge.fromMap].
  static List<CtaOverride>? tryParseList(dynamic raw) {
    if (raw == null) return null;
    if (raw is! List) return null;
    final ctas = raw
        .map((e) {
          if (e is Map) {
            return CtaOverride.tryFromMap(Map<String, dynamic>.from(e));
          }
          return null;
        })
        .whereType<CtaOverride>()
        .toList();
    return ctas.isEmpty ? null : ctas;
  }
}
