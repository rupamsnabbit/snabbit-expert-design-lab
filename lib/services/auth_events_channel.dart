import 'dart:async';

import 'package:flutter/services.dart';

/// Dart subscription to the KMP module's `com.snabbit.runner/auth_events`
/// EventChannel. Mirrors the EventChannel half of
/// `android/app/src/main/kotlin/com/snabbit/runner/kmp_bridge/AuthPlugin.kt`.
///
/// Events are typed maps: `{"type": "unauthorized"}`. The channel is shaped
/// to carry future events (forced logout, session expired) without needing
/// a new channel.
class AuthEventsChannel {
  AuthEventsChannel._();

  static const EventChannel _channel =
      EventChannel('com.snabbit.runner/auth_events');

  /// Installs a callback fired when KMP observes a 401. Returns a
  /// [StreamSubscription] the caller can cancel on dispose.
  ///
  /// Idempotent on the native side via `UnauthorizedResponseObserver`'s
  /// 2-second debounce — a burst of 401s fires this once.
  static StreamSubscription<void> onUnauthorized(void Function() handler) {
    return _channel
        .receiveBroadcastStream()
        .where((event) => event is Map && event['type'] == 'unauthorized')
        .listen((_) => handler());
  }
}
