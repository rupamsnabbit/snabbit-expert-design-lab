import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';

/// Receives KMP-side crash reports via MethodChannel and forwards them
/// to [MonitoringServiceHelper.logError] — same pipeline Coralogix uses
/// for native Dart errors. KMP-originated entries are tagged with
/// `source: 'kmp'` for filterability.
///
/// Wire shape (KMP → Dart):
///
/// ```
/// method: 'report'
/// args:   { op, exception, message, stackTrace, meta }
/// ```
///
/// `op` is the high-level operation tag (e.g. `providerStart`,
/// `hydrateAll`, `kmpBootstrap`); `meta` is the original key/value map
/// the KMP caller passed to `crashReporter.report(...)`. Both are
/// expanded into the Coralogix payload alongside the throwable summary.
class KmpCrashReporterBridge {
  KmpCrashReporterBridge._();

  static const _channel = MethodChannel('com.snabbit.runner/crash_reporter');

  /// Wires the Kotlin → Dart receive side. Call once from `main()`
  /// before `runApp` so reports arriving during the first frame have
  /// somewhere to land.
  static void initialize() {
    _channel.setMethodCallHandler(_handle);
  }

  static Future<Object?> _handle(MethodCall call) async {
    if (call.method != 'report') return null;
    final args = (call.arguments as Map?)?.cast<String, dynamic>() ?? const {};
    final op = args['op']?.toString() ?? 'unknown';
    final exception = args['exception']?.toString() ?? '';
    final message = args['message']?.toString() ?? '';
    final stack = args['stackTrace']?.toString() ?? '';
    final meta = (args['meta'] as Map?)?.cast<String, dynamic>() ?? const {};

    MonitoringServiceHelper.logError('kmp_error', {
      'source': 'kmp',
      'op': op,
      'exception': exception,
      'message': message,
      'stack': stack,
      ...meta,
    }).catchError((e) {
      if (kDebugMode) debugPrint('KmpCrashReporterBridge forward failed: $e');
    });
    return null;
  }
}
