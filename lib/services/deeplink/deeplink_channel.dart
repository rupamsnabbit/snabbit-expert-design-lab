import 'package:flutter/services.dart';

/// Dart side of the KMP OneLink bridge (`DeeplinkPlugin.kt`). Surfaces
/// AppsFlyer-resolved Unified Deep Linking (UDL) params as raw maps; mapping to
/// an in-app route is the router's job ([DeepLinkRouter.mapOneLinkParams]).
///
/// Mirrors the `KmpBridge` / `AuthTokenChannel` MethodChannel pattern, plus an
/// EventChannel for the asynchronous UDL stream.
class DeeplinkChannel {
  DeeplinkChannel._();

  static const MethodChannel _method =
      MethodChannel('com.snabbit.runner/deeplink');
  static const EventChannel _events =
      EventChannel('com.snabbit.runner/deeplink_events');

  /// Cold-start drain: returns a UDL link that resolved before the [deeplinks]
  /// stream was attached, or null. Consumed once on the native side.
  static Future<Map<String, dynamic>?> getInitialDeeplink() async {
    final result =
        await _method.invokeMethod<Map<dynamic, dynamic>>('getInitialDeeplink');
    return result == null ? null : Map<String, dynamic>.from(result);
  }

  /// Stream of UDL-resolved raw param maps while the app is running.
  static Stream<Map<String, dynamic>> get deeplinks => _events
      .receiveBroadcastStream()
      .map((event) => Map<String, dynamic>.from(event as Map));
}
