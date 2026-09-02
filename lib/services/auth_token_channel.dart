import 'package:flutter/services.dart';

/// Dart wrapper over the KMP module's `com.snabbit.runner/auth`
/// MethodChannel. Mirrors `pushToken` / `clearToken` on
/// `android/app/src/main/kotlin/com/snabbit/runner/kmp_bridge/AuthPlugin.kt`.
///
/// Auth state writer. Paired with [AuthEventsChannel] (the EventChannel
/// for 401 notifications) — both are owned by the same native plugin so
/// state stays coupled.
class AuthTokenChannel {
  AuthTokenChannel._();

  static const MethodChannel _channel = MethodChannel('com.snabbit.runner/auth');

  /// Hands KMP the current bearer token. Persisted in the encrypted store
  /// so it survives process death.
  static Future<void> pushToken(String token) async {
    await _channel.invokeMethod<void>('pushToken', <String, Object?>{
      'token': token,
    });
  }

  /// Wipes the bearer token from KMP's in-memory flow and encrypted store.
  /// Called on logout and on 401 (via [AuthEventsChannel]).
  static Future<void> clearToken() async {
    await _channel.invokeMethod<void>('clearToken');
  }
}
