import 'package:snabbit_runner/models/gamification/cta_override.dart';
import 'package:snabbit_runner/models/gamification/pre_action_nudge.dart';
import 'package:snabbit_runner/models/gamification/sheet_warning.dart';

/// Singleton entry for gamification parsing. Public methods must not throw.
class GamificationManager {
  GamificationManager._();
  static final GamificationManager instance = GamificationManager._();

  /// [envelope] is optional full `runnerAppCurrentState` JSON — same top-level
  /// `pre_action_nudges` / `preActionNudges` as [sheet_warnings] (see BACKEND_SHEET_WARNINGS.md).
  List<PreActionNudge> parseNudges(
    Map<String, dynamic>? widgetData, [
    Map<String, dynamic>? envelope,
  ]) {
    try {
      final fromWidget =
          widgetData?['preActionNudges'] ?? widgetData?['pre_action_nudges'];
      final raw = fromWidget ??
          envelope?['preActionNudges'] ??
          envelope?['pre_action_nudges'];
      if (raw is! List) return [];
      final out = <PreActionNudge>[];
      for (final item in raw) {
        if (item is Map<String, dynamic>) {
          final n = PreActionNudge.tryFromMap(item);
          if (n != null) out.add(n);
        } else if (item is Map) {
          final n = PreActionNudge.tryFromMap(Map<String, dynamic>.from(item));
          if (n != null) out.add(n);
        }
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  /// Top-level **`sheet_warnings`** (canonical; `sheetWarnings` alias) on runner
  /// current state. Drops items whose `expiresAt` is in the past.
  List<SheetWarning> parseSheetWarnings(dynamic raw) {
    try {
      if (raw is! List) return [];
      final out = <SheetWarning>[];
      for (final item in raw) {
        if (item is Map<String, dynamic>) {
          final w = SheetWarning.tryFromMap(item);
          if (w != null && !_isStale(w.expiresAt)) out.add(w);
        } else if (item is Map) {
          final w = SheetWarning.tryFromMap(Map<String, dynamic>.from(item));
          if (w != null && !_isStale(w.expiresAt)) out.add(w);
        }
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  static bool _isStale(DateTime? expiresAt) {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt);
  }

  /// Last override wins per CTA id (case-insensitive key) if duplicates appear across nudges.
  Map<String, CtaOverride> resolveCtaOverridesFromNudges(
      List<PreActionNudge> nudges) {
    final map = <String, CtaOverride>{};
    for (final n in nudges) {
      final list = n.ctaOverrides;
      if (list == null) continue;
      for (final o in list) {
        map[o.ctaId.toLowerCase()] = o;
      }
    }
    return map;
  }

  /// Last override wins per CTA id (case-insensitive key) across sheet warnings.
  Map<String, CtaOverride> resolveCtaOverrides(List<SheetWarning> warnings) {
    final map = <String, CtaOverride>{};
    for (final w in warnings) {
      final list = w.ctaOverrides;
      if (list == null) continue;
      for (final o in list) {
        map[o.ctaId.toLowerCase()] = o;
      }
    }
    return map;
  }
}
