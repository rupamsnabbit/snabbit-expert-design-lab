/// Outcome of routing a deeplink through `DeepLinkRouter`.
///
/// Three states are all the caller needs:
/// - [handled]: navigated — either to the destination or to the Home fallback.
///   The caller stops.
/// - [queued]: the app wasn't routable yet (cold start / logged out); the link
///   was parked in the single pending slot and will fire when PartnerHome
///   mounts. The caller stops.
/// - [notHandled]: the router did not consume the link (the `enableDeeplinks`
///   kill switch is off). The caller falls through to the legacy
///   notification-`type` switch so existing behaviour is unchanged.
///
/// Finer reasons (unknown path, empty URL, parse failure) are logged as a
/// reason string rather than encoded as separate states.
enum DeepLinkResult { handled, queued, notHandled }

/// Where an inbound deeplink originated — for analytics/telemetry only.
enum DeeplinkSource {
  /// FCM data-message notification tap.
  notification,

  /// CleverTap push (foreground/background click or killed-state launch).
  clevertap,

  /// AppsFlyer OneLink, resolved natively via the KMP bridge.
  onelink,
}

extension DeeplinkSourceName on DeeplinkSource {
  String get analyticsName {
    switch (this) {
      case DeeplinkSource.notification:
        return 'notification';
      case DeeplinkSource.clevertap:
        return 'clevertap';
      case DeeplinkSource.onelink:
        return 'onelink';
    }
  }
}
