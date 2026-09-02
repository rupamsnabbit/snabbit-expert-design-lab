import 'package:flutter/services.dart';

/// Debug bridge to the KMP shared module's `HelloModule`. Mirrors
/// `android/app/src/main/kotlin/com/snabbit/runner/kmp_bridge/KmpHelloPlugin.kt`.
/// Used only by the debug menu to verify the bridge is wired end-to-end.
/// For production network operations see [NetworkChannel]; for the native
/// Language screen see [LanguageChannel].
class KmpBridge {
  static const _channel = MethodChannel('com.snabbit.runner/kmp_hello');

  /// Calls the `hello` exemplar module. Used by the debug menu.
  static Future<String> getHelloMessage() async {
    final result = await _channel.invokeMethod<String>('getHelloMessage');
    return result ?? 'No response from KMP';
  }
}
