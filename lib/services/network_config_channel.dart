import 'package:flutter/services.dart';

/// Dart wrapper over the KMP module's `com.snabbit.runner/network_config`
/// MethodChannel. Mirrors
/// `android/app/src/main/kotlin/com/snabbit/runner/kmp_bridge/NetworkConfigPlugin.kt`.
///
/// Pure config writer — no auth concerns. Pushes `baseUrl` + `versionCode`
/// so KMP's HTTP client can resolve URLs and set the `x-version-code`
/// header.
class NetworkConfigChannel {
  NetworkConfigChannel._();

  static const MethodChannel _channel =
      MethodChannel('com.snabbit.runner/network_config');

  /// Pushes baseUrl + versionCode (+ optional onboardingUrl for the onboarding
  /// host, used by KMP's PAN update). Idempotent — safe to call repeatedly with
  /// the same values.
  static Future<void> pushConfig({
    required String baseUrl,
    required String versionCode,
    String? onboardingUrl,
    String? appVersion,
    bool? isProd,
  }) async {
    await _channel.invokeMethod<void>('pushConfig', <String, Object?>{
      'baseUrl': baseUrl,
      'versionCode': versionCode,
      if (onboardingUrl != null) 'onboardingUrl': onboardingUrl,
      if (appVersion != null) 'appVersion': appVersion,
      if (isProd != null) 'isProd': isProd,
    });
  }
}
