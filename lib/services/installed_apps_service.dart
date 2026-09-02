import 'package:flutter/services.dart';
import 'package:snabbit_runner/services/clevertap.dart';

/// Detects installed apps and logs to CleverTap.
/// Uses platform channel - only checks packages declared in AndroidManifest `<queries>`.
class InstalledAppService {
  static const _channel = MethodChannel('com.snabbit.runner/app_check');

  static const List<String> _packages = [
    'com.urbanclap.provider',
    'com.company.prontopartner',
  ];

  /// Check for installed apps and log to CleverTap.
  /// Fire-and-forget - call without await.
  static Future<void> checkAndLog() async {
    try {
      final installed = <String>[];
      for (final pkg in _packages) {
        final isInstalled = await _channel.invokeMethod<bool>(
          'isAppInstalled',
          {'packageName': pkg},
        );
        if (isInstalled == true) {
          installed.add(pkg);
        }
      }
      await ClevertapSetup.logEvent('installed_apps_check', {
        'installed_apps': installed.join(','),
        'count': installed.length,
      });
    } catch (_) {}
  }
}
