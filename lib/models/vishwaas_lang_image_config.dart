/// Language-based image + optional action URL. Nested under
/// `VishwaasBannerRemoteConfig` (`drawer` / `provisional_attendance_sheet`) or
/// as one flat object for both surfaces.
class VishwaasLangImageConfig {
  VishwaasLangImageConfig({
    required this.imageByLang,
    this.fallbackLang,
    this.actionUrl,
  });

  final Map<String, String> imageByLang;
  final String? fallbackLang;
  final String? actionUrl;

  /// Returns null if JSON is missing or not usable.
  static VishwaasLangImageConfig? tryParse(Map<String, dynamic>? json) {
    if (json == null) return null;
    final raw = json['image_by_lang'];
    if (raw is! Map) return null;
    final imageByLang = <String, String>{};
    for (final entry in raw.entries) {
      final v = entry.value;
      if (v is String && v.trim().isNotEmpty) {
        imageByLang[entry.key.toString()] = v.trim();
      }
    }
    if (imageByLang.isEmpty) return null;
    final action = json['action_url'];
    return VishwaasLangImageConfig(
      imageByLang: imageByLang,
      fallbackLang: json['fallback_lang'] is String
          ? (json['fallback_lang'] as String).trim().isEmpty
              ? null
              : (json['fallback_lang'] as String).trim()
          : null,
      actionUrl: action is String && action.trim().isNotEmpty
          ? action.trim()
          : null,
    );
  }

  String? resolveImageUrl(String? languagePreference) {
    if (languagePreference != null) {
      final u = imageByLang[languagePreference];
      if (u != null && u.isNotEmpty) return u;
    }
    final fb = fallbackLang;
    if (fb != null) {
      final u = imageByLang[fb];
      if (u != null && u.isNotEmpty) return u;
    }
    for (final u in imageByLang.values) {
      if (u.isNotEmpty) return u;
    }
    return null;
  }
}
