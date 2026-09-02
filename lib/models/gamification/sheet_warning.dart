import 'package:flutter/foundation.dart';
import 'package:snabbit_runner/models/gamification/cta_override.dart';

/// A sheet-warning row from the top-level `sheet_warnings[]` API field.
///
/// Unlike [PreActionNudge], the UI never reads `label` or `iconUrl` from these
/// rows — it only uses [lifecycleActionType] to match the right attendance
/// sheet and [ctaOverrides] for button labels / badges / red-card counts.
class SheetWarning {
  final String lifecycleActionType;
  final List<CtaOverride>? ctaOverrides;
  final DateTime? expiresAt;

  const SheetWarning({
    required this.lifecycleActionType,
    this.ctaOverrides,
    this.expiresAt,
  });

  bool get hasCtaOverrides =>
      ctaOverrides != null && ctaOverrides!.isNotEmpty;

  factory SheetWarning.fromMap(Map<String, dynamic> map) {
    final expiresRaw = map['expiresAt'] ?? map['expires_at'];
    return SheetWarning(
      lifecycleActionType: map['lifecycleActionType']?.toString() ??
          map['lifecycle_action_type']?.toString() ??
          '',
      ctaOverrides: CtaOverride.tryParseList(
        map['ctaOverrides'] ?? map['cta_overrides'],
      ),
      expiresAt: expiresRaw != null
          ? DateTime.tryParse(expiresRaw.toString())
          : null,
    );
  }

  static SheetWarning? tryFromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    try {
      final w = SheetWarning.fromMap(map);
      if (w.lifecycleActionType.isEmpty) return null;
      return w;
    } catch (e, st) {
      debugPrint('[SheetWarning] parse error: $e\n$st');
      return null;
    }
  }
}
