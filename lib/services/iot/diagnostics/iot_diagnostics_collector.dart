import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:snabbit_runner/models/iot_diagnostic_event.dart';
import 'package:snabbit_runner/services/database/database_factory.dart';
import 'package:snabbit_runner/services/database/database_interface.dart';

/// Writes diagnostic events to SQLite. Safe to call from any isolate.
/// No analytics SDK dependencies — only uses the database layer.
class IotDiagnosticsCollector {
  final IDatabaseInterface _db;

  IotDiagnosticsCollector({IDatabaseInterface? database})
      : _db = database ?? DatabaseFactory.getInstance();

  // --- App foreground/background context, stamped on every diagnostic ---
  // The IoT collectors run in the background-service isolate, which can't see
  // the app's foreground state directly. The main isolate persists it on each
  // lifecycle change ([persistLifecycle]); the bg manager loads it once per
  // cycle ([refreshLifecycleFromPrefs]) into these statics (shared within the
  // bg isolate). Stamping is_fg at EMIT time makes it robust to deferred-flush
  // timestamp distortion. Null = unknown (not yet learned).
  static const _kIsForegroundKey = 'iot_app_is_foreground';
  static const _kLifecycleTsKey = 'iot_app_lifecycle_ts';

  static bool? isForeground;
  static int? lifecycleUpdatedAtMs;

  // Set once per background-service start (see main.dart startBgLocService).
  // A jump in bg_restart_count between a device's diagnostics reveals kill/
  // restart churn even though a killed isolate can't report its own death.
  static String? bgBootSessionId;
  static int? bgRestartCount;

  /// Called from the MAIN isolate on every app lifecycle change.
  static Future<void> persistLifecycle(bool isForegroundState) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kIsForegroundKey, isForegroundState);
      await prefs.setInt(
          _kLifecycleTsKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  /// Called from the BG isolate (once per cycle) to load the latest lifecycle.
  static Future<void> refreshLifecycleFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      if (prefs.containsKey(_kIsForegroundKey)) {
        isForeground = prefs.getBool(_kIsForegroundKey);
        lifecycleUpdatedAtMs = prefs.getInt(_kLifecycleTsKey);
      }
    } catch (_) {}
  }

  Future<void> logDiagnostic(
    String eventName,
    Map<String, dynamic> data,
  ) async {
    try {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final enriched = <String, dynamic>{
        ...data,
        'is_fg': isForeground,
        if (lifecycleUpdatedAtMs != null)
          'fg_state_age_ms': nowMs - lifecycleUpdatedAtMs!,
        if (bgBootSessionId != null) 'bg_session_id': bgBootSessionId,
        if (bgRestartCount != null) 'bg_restart_count': bgRestartCount,
      };
      final event = IotDiagnosticEvent(
        eventName: eventName,
        eventData: enriched,
        createdAt: nowMs,
      );
      await _db.insert(DatabaseTables.diagnosticEvents, event.toMap());
    } catch (_) {
      // Diagnostics must never crash the app
    }
  }

  /// Captures current process memory (RSS) in megabytes.
  /// Returns -1 if unavailable.
  static double getMemoryRssMb() {
    try {
      return ProcessInfo.currentRss / (1024 * 1024);
    } catch (_) {
      return -1;
    }
  }
}
