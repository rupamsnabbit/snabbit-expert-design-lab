import 'package:flutter/services.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';

/// One-way bridge for the backend app-config document. Mirrors
/// `android/app/src/main/kotlin/com/snabbit/runner/kmp_bridge/AppConfigPlugin.kt`
/// and lands in the KMP `AppConfigStore` (a `MutableStateFlow`) that :shared
/// features decode their config slices from (first consumer: the delayed
/// check-in `job_support` options, FR-11).
///
/// Dart → KMP only: `GlobalState.setAppConfig()` pushes the raw response body
/// once after its startup fetch (no retry, aligning with #421). There is no
/// KMP-initiated refresh — see `RunnerStateChannel` for the bidirectional
/// sibling.
///
/// Modelled on `RunnerStateChannel`: a thin static writer. [pushConfig] is
/// best-effort — any channel failure is swallowed and logged (sanitized) so a
/// bridge hiccup can never disturb the Dart-side startup sequence.
class AppConfigChannel {
  AppConfigChannel._();

  static const MethodChannel _channel =
      MethodChannel('com.snabbit.runner/app_config');

  /// Pushes the app-config document (already JSON-encoded) to KMP. Never
  /// throws — failures are logged and absorbed.
  static Future<void> pushConfig(String json) {
    return _channel.invokeMethod<void>('pushConfig', <String, Object?>{
      'json': json,
    }).catchError((e) => _logFailure('pushConfig', e));
  }

  /// Records the *kind* of failure (PlatformException code or runtime type)
  /// but never the exception message — mirrors `RunnerStateChannel`'s
  /// defense-in-depth rule against echoing payloads into logs.
  static void _logFailure(String op, Object e) {
    final tag = e is PlatformException
        ? 'PlatformException(${e.code})'
        : e.runtimeType.toString();
    MonitoringServiceHelper.logError('app_config_channel_error', {
      'op': op,
      'error': tag,
    }).catchError((_) {});
  }
}
