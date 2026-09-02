import 'package:snabbit_runner/models/vishwaas_lang_image_config.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_keys.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_service.dart';

/// Single Remote Config parameter (`expert_vishwaas_banner`) can drive the drawer
/// and the ProvisionalAttendance bottom sheet.
///
/// **Nested (recommended):**
/// ```json
/// {
///   "drawer": { "image_by_lang": { "ENGLISH": "https://..." }, "fallback_lang": "ENGLISH", "action_url": "https://..." },
///   "provisional_attendance_sheet": { "image_by_lang": { "ENGLISH": "https://..." }, "fallback_lang": "ENGLISH", "action_url": "https://..." }
/// }
/// ```
///
/// **Legacy (same assets for both):** a flat [VishwaasLangImageConfig] object
/// (top-level `image_by_lang`, etc.) — applies to both surfaces.
///
/// **Migration:** if `expert_vishwaas_banner` is empty/invalid, falls back to
/// [RemoteConfigKeys.expertVishwaasDrawerBanner] (flat) when present.
class VishwaasBannerRemoteConfig {
  const VishwaasBannerRemoteConfig({
    this.drawer,
    this.provisionalAttendanceSheet,
  });

  final VishwaasLangImageConfig? drawer;
  final VishwaasLangImageConfig? provisionalAttendanceSheet;

  static Map<String, dynamic>? _asMap(dynamic v) {
    if (v == null) return null;
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }

  static VishwaasBannerRemoteConfig? tryParse(Map<String, dynamic>? json) {
    if (json == null) return null;
    final hasNested = json.containsKey('drawer') ||
        json.containsKey('provisional_attendance_sheet');
    if (hasNested) {
      final d = VishwaasLangImageConfig.tryParse(_asMap(json['drawer']));
      final p = VishwaasLangImageConfig.tryParse(
        _asMap(json['provisional_attendance_sheet']),
      );
      if (d == null && p == null) return null;
      return VishwaasBannerRemoteConfig(
        drawer: d,
        provisionalAttendanceSheet: p,
      );
    }
    final shared = VishwaasLangImageConfig.tryParse(json);
    if (shared == null) return null;
    return VishwaasBannerRemoteConfig(
      drawer: shared,
      provisionalAttendanceSheet: shared,
    );
  }

  /// Reads [RemoteConfigKeys.expertVishwaasBanner], then legacy drawer key.
  static VishwaasBannerRemoteConfig? load() {
    final rc = RemoteConfigService.instance;
    return tryParse(rc.getJson(RemoteConfigKeys.expertVishwaasBanner)) ??
        tryParse(rc.getJson(RemoteConfigKeys.expertVishwaasDrawerBanner));
  }
}
