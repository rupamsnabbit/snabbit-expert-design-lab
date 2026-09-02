import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:snabbit_runner/models/iot_diagnostic_event.dart';
import 'package:snabbit_runner/services/database/database_factory.dart';
import 'package:snabbit_runner/services/database/database_interface.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';

/// Reads queued diagnostic events from SQLite and dispatches them
/// to analytics services. Must run in the main isolate where SDKs
/// are initialized.
///
/// All events go to Coralogix (observability).
/// Only critical, aggregatable events go to CleverTap/Mixpanel
/// (product analytics — billed per event).
class IotDiagnosticsReporter {
  final IDatabaseInterface _db;

  IotDiagnosticsReporter({IDatabaseInterface? database})
      : _db = database ?? DatabaseFactory.getInstance();

  // Guards against overlapping flushes — resume + pause + the periodic timer
  // can all fire. Stores the in-flight flush's start time (not a bool) so a
  // hung flush can't permanently disable flushing: after [_flushStaleMs] we
  // assume it died and allow re-entry. Static because callers use fresh
  // IotDiagnosticsReporter() instances.
  static int _flushInProgressSince = 0;
  static const int _flushStaleMs = 120000;

  /// Flush queued diagnostic events to Coralogix.
  ///
  /// Drains the backlog in bounded batches so a device that accumulated events
  /// while backgrounded catches up in a single foreground flush, instead of
  /// 50-at-a-time (which never kept up on rarely-foregrounding devices). Stops
  /// when the queue is drained, when a batch makes no forward progress, or
  /// after [maxBatchesPerRun] batches.
  Future<void> flushDiagnostics({int maxBatchesPerRun = 20}) async {
    final startedAt = DateTime.now().millisecondsSinceEpoch;
    if (_flushInProgressSince != 0 &&
        startedAt - _flushInProgressSince < _flushStaleMs) {
      return;
    }
    _flushInProgressSince = startedAt;
    try {
      const batchSize = 50;
      for (int batch = 0; batch < maxBatchesPerRun; batch++) {
        final rows = await _db.query(
          DatabaseTables.diagnosticEvents,
          where: 'processed = ?',
          whereArgs: [0],
          orderBy: 'created_at ASC',
          limit: batchSize,
        );

        if (rows.isEmpty) break;

        final events = rows.map((r) => IotDiagnosticEvent.fromMap(r)).toList();
        int eventCounter = 0;
        int deletedThisBatch = 0;
        String? lastEvent;

        for (final event in events) {
          try {
            // All events go to Coralogix. Merge the original event time so
            // late-flushed diagnostics carry their TRUE emit time (createdAt),
            // not the flush time — flush can lag hours on rarely-foregrounding
            // devices, which otherwise corrupts all time-windowed analysis.
            await MonitoringServiceHelper.logDebug(
              event.eventName,
              {
                ...event.eventData,
                'event_time_ms': event.createdAt,
              },
            );
            if (lastEvent != event.eventName) {
              if (lastEvent != null) {
                FirebaseCrashlytics.instance.log(
                    "flushed $eventCounter events: counts by $lastEvent");
              }
              lastEvent = event.eventName;
              eventCounter = 1;
            } else {
              eventCounter++;
            }

            if (event.id != 0) {
              await _db.delete(
                DatabaseTables.diagnosticEvents,
                where: 'id = ?',
                whereArgs: [event.id],
              );
              deletedThisBatch++;
            }
          } catch (e, st) {
            // Individual event failure shouldn't block the rest
            MonitoringServiceHelper.logError(
              "IOT_FLUSH_DIAGNOSTICS_EVENT_LEVEL_ERROR",
              {
                "error": e.toString(),
                "stacktrace": st.toString(),
                "event_name": event.eventName,
                "event_data": event.eventData
              },
            );

            FirebaseCrashlytics.instance.recordError(e, st);
          }
        }
        if (lastEvent != null) {
          FirebaseCrashlytics.instance
              .log("flushed $eventCounter '$lastEvent' events");
        }

        // Stop if the queue is drained, or if this batch made no forward
        // progress (head events keep failing) to avoid spinning on them.
        if (rows.length < batchSize || deletedThisBatch == 0) break;
      }
    } catch (e, st) {
      // Diagnostics flush must never crash the app
      MonitoringServiceHelper.logError(
        "IOT_FLUSH_DIAGNOSTICS_ERROR",
        {
          "error": e.toString(),
          "stacktrace": st.toString(),
        },
      );

      FirebaseCrashlytics.instance.recordError(e, st);
    } finally {
      // Only clear if we still own the guard. A flush that overran
      // [_flushStaleMs] can be superseded by a newer flush; clearing
      // unconditionally would wipe the newer flush's guard and let a third
      // flush run concurrently and double-read the same unprocessed rows.
      if (_flushInProgressSince == startedAt) _flushInProgressSince = 0;
    }
  }

  /// Delete old diagnostic events to bound table growth.
  ///
  /// [flushDiagnostics] already deletes events as soon as they're shipped, so
  /// the rows still present here are UNFLUSHED — typically from a device that
  /// rarely foregrounds, where the main isolate (which owns the analytics
  /// SDKs) hasn't run to flush them. Deleting these after just 24h made us
  /// blind to exactly those devices' background-location failures, so we retain
  /// them for [maxAgeMs] (default 7 days) to give them a chance to flush the
  /// next time the app is opened.
  Future<int> cleanupOldEvents({int maxAgeMs = 604800000}) async {
    try {
      final cutoff = DateTime.now().millisecondsSinceEpoch - maxAgeMs;
      return await _db.delete(
        DatabaseTables.diagnosticEvents,
        where: 'created_at < ?',
        whereArgs: [cutoff],
      );
    } catch (_) {
      return 0;
    }
  }
}
