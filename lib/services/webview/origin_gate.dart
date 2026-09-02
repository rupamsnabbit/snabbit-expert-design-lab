/// Exact-origin allowlist for inbound bifrost messages. See proposal §2.6.
///
/// The gate is initialised with the webview's initial URL at open time; this
/// forms the primary allowlist. A secondary allowlist (for OAuth returns etc.)
/// is optional and empty by default. Fail-closed: a null or unparseable
/// current URL is rejected. An invalid initial URL leaves the allowlist
/// empty and blocks everything — callers should validate URLs upstream.
class OriginGate {
  OriginGate({
    required String initialUrl,
    Iterable<String> additionalOrigins = const [],
  }) : _allowed = <String>{
          if (_originOf(initialUrl) case final o?) o,
          for (final origin in additionalOrigins)
            if (_originOf(origin) case final o?) o,
        };

  final Set<String> _allowed;

  /// Returns true iff [currentUrl]'s origin exactly matches an allowed
  /// origin. Null / blank / unparseable URLs are always denied.
  bool isAllowed(String? currentUrl) {
    if (currentUrl == null || currentUrl.isEmpty) return false;
    final origin = _originOf(currentUrl);
    if (origin == null) return false;
    return _allowed.contains(origin);
  }

  /// Exposed for logging.
  Set<String> get allowedOrigins => Set.unmodifiable(_allowed);

  static String? _originOf(String url) {
    try {
      final uri = Uri.parse(url);
      if (!uri.hasScheme || uri.host.isEmpty) return null;
      return uri.origin;
    } catch (_) {
      return null;
    }
  }
}
