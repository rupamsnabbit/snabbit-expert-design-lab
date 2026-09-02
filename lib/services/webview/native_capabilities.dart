/// The set of bifrost capabilities this native build supports. Reported to
/// the web on `requestInitData` (see proposal §2.8) so the web can
/// feature-detect without needing version numbers.
///
/// Guidelines for editing this list:
///  - Add an entry when a new bifrost *action* ships. URIs inside `navigate`
///    are NOT capabilities — those are registry-level and return
///    `UNKNOWN_ROUTE` if unsupported.
///  - Entries are stable identifiers, `camelCase` to match action names.
///    Once shipped, never rename.
///  - Table-stakes actions (`openUrl`, `callPhone`, `closeWebView`,
///    `requestInitData`) are intentionally omitted — they've always existed
///    and no web client needs to feature-detect them.
class NativeCapabilities {
  NativeCapabilities._();

  static const Set<String> supported = {
    'navigate',
    'trackEvent',
    'tokenExpired',
    'permissionRequest',
    'captureImage',
    'cancelCapture',
    'releaseCapture',
    'goLiveComplete',
    'deviceStorage',
    'openPerfiosAadhaar',
    'speak',
  };

  /// Returns the subset of [requested] that this build supports, preserving
  /// the web's order (useful when web wants a deterministic array). Null or
  /// empty input yields an empty result — web opts in to capability
  /// negotiation by passing the list.
  static List<String> intersect(Iterable<String>? requested) {
    if (requested == null) return const [];
    return requested.where(supported.contains).toList(growable: false);
  }
}
