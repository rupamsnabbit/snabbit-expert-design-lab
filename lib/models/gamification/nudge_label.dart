class NudgeLabel {
  final String key;
  final Map<String, dynamic>? params;

  /// Server copy fallback when localization bundle has no entry (see `default_text` in API).
  final String? defaultText;

  const NudgeLabel({required this.key, this.params, this.defaultText});

  /// [raw] is either `{ "key", "params" }` or a legacy plain string (deprecated).
  factory NudgeLabel.fromDynamic(dynamic raw, {String? legacyTitle}) {
    if (raw == null) {
      final t = legacyTitle;
      if (t != null && t.isNotEmpty) {
        return NudgeLabel(key: 'legacy_literal', params: {'text': t});
      }
      return const NudgeLabel(key: '', params: null);
    }
    if (raw is Map<String, dynamic>) {
      final k = raw['key'];
      return NudgeLabel(
        key: k is String ? k : '',
        params: _normalizeParams(_castParams(raw['params'])),
        defaultText: raw['default_text'] as String? ?? raw['defaultText'] as String?,
      );
    }
    if (raw is Map) {
      final k = raw['key'];
      return NudgeLabel(
        key: k is String ? k : '',
        params: _normalizeParams(_castParams(raw['params'])),
        defaultText: raw['default_text'] as String? ?? raw['defaultText'] as String?,
      );
    }
    if (raw is String) {
      return NudgeLabel(key: 'legacy_literal', params: {'text': raw});
    }
    return const NudgeLabel(key: '', params: null);
  }

  static Map<String, dynamic>? _castParams(dynamic p) {
    if (p == null) return null;
    if (p is Map<String, dynamic>) return p;
    if (p is Map) {
      return p.map((k, v) => MapEntry('$k', v));
    }
    return null;
  }

  /// Duplicate snake_case keys as camelCase so `{{redCards}}` templates work with Python-style JSON.
  static Map<String, dynamic>? _normalizeParams(Map<String, dynamic>? p) {
    if (p == null) return null;
    final out = Map<String, dynamic>.from(p);
    if (out.containsKey('red_cards') && !out.containsKey('redCards')) {
      out['redCards'] = out['red_cards'];
    }
    if (out.containsKey('gold_coins') && !out.containsKey('goldCoins')) {
      out['goldCoins'] = out['gold_coins'];
    }
    if (out.containsKey('deadline_time') && !out.containsKey('deadlineTime')) {
      out['deadlineTime'] = out['deadline_time'];
    }
    return out;
  }

  bool get isValid => key.isNotEmpty;
}
