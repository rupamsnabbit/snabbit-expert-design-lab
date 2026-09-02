import 'package:flutter/services.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';

/// Dart → KMP writer for the server-driven i18n map + current language. Mirrors
/// `android/app/src/main/kotlin/com/snabbit/runner/kmp_bridge/LocalizationPlugin.kt`
/// and lands in the KMP `LocalizationStore` (a `MutableStateFlow`) that the
/// Expert App 2.0 Compose Multiplatform surfaces look copy up against.
///
/// One-way, modelled on `RunnerStateChannel`: a thin static writer.
/// `LanguageProvider` is the single source of truth (it owns the HTTP fetch)
/// and pushes on every language settle — cold-start restore + each change;
/// this class only carries the bytes across.
///
/// [pushMessages] is best-effort — any channel failure is swallowed and logged
/// (sanitized) so a bridge hiccup can never disturb the language-apply flow it
/// is awaited on.
class LocalizationChannel {
  LocalizationChannel._();

  static const MethodChannel _channel =
      MethodChannel('com.snabbit.runner/localization');

  /// Pushes the full i18n map (already JSON-encoded) + the current [language]
  /// preference (e.g. `"ENGLISH"`) to KMP. Never throws — failures are logged
  /// and absorbed.
  static Future<void> pushMessages({
    required String language,
    required String messagesJson,
  }) {
    return _channel.invokeMethod<void>('pushMessages', <String, Object?>{
      'language': language,
      'messagesJson': messagesJson,
    }).catchError((e) => _logFailure('pushMessages', e));
  }

  /// Records the *kind* of failure (PlatformException code or runtime type)
  /// but never the exception message — defense-in-depth, matching
  /// `RunnerStateChannel`.
  static void _logFailure(String op, Object e) {
    final tag = e is PlatformException
        ? 'PlatformException(${e.code})'
        : e.runtimeType.toString();
    MonitoringServiceHelper.logError('localization_channel_error', {
      'op': op,
      'error': tag,
    }).catchError((_) {});
  }
}
