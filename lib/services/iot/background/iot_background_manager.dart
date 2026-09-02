import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:logger/logger.dart';
import 'package:snabbit_runner/services/database/database_factory.dart';
import 'package:snabbit_runner/services/iot/cleanup/cleanup_job.dart';
import 'package:snabbit_runner/services/iot/collectors/battery_collector.dart';
import 'package:snabbit_runner/services/iot/collectors/device_state_collector.dart';
import 'package:snabbit_runner/services/iot/collectors/location_collector.dart';
import 'package:snabbit_runner/services/iot/config/config_service.dart';
import 'package:snabbit_runner/services/iot/diagnostics/iot_diagnostics_collector.dart';
import 'package:snabbit_runner/services/iot/sender/sender.dart';

/// Manages IoT background jobs: collection, sending, and cleanup
/// Designed to run in background service isolate
class IotBackgroundManager {
  static void _reportError(Object error, StackTrace stackTrace, String reason) {
    FirebaseCrashlytics.instance.log(reason);
    FirebaseCrashlytics.instance.recordError(error, stackTrace, reason: reason, fatal: false);
  }

  static void _logBreadcrumb(String message) {
    FirebaseCrashlytics.instance.log(message);
  }

  static final Logger _logger = Logger();

  final ConfigService _config;
  final BatteryCollector _batteryCollector;
  final LocationCollector _locationCollector;
  final Sender _sender;
  final CleanupJob _cleanupJob;
  final DeviceStateCollector _deviceStateCollector;
  final IotDiagnosticsCollector _diagnostics;

  // Track last run times for each job
  int _lastBatteryCollection = 0;
  int _lastLocationCollection = 0;
  int _lastSendAttempt = 0;
  int _lastCleanup = 0;
  int _lastDeviceStateCollection = 0;
  bool _isRunning = false;

  // Track last skip-event emission per job so we don't flood Coralogix on every
  // 10s timer tick. A skip event is emitted at most once per job-interval window.
  int _lastBatterySkipLog = 0;
  int _lastLocationSkipLog = 0;
  int _lastSendSkipLog = 0;
  int _lastDeviceStateSkipLog = 0;

  // Consecutive location failure tracking
  int _consecutiveLocationFailures = 0;
  String _lastLocationError = '';


  IotBackgroundManager({
    ConfigService? config,
    BatteryCollector? batteryCollector,
    LocationCollector? locationCollector,
    Sender? sender,
    CleanupJob? cleanupJob,
    DeviceStateCollector? deviceStateCollector,
    IotDiagnosticsCollector? diagnostics,
  })  : _config = config ?? ConfigService.instance,
        _batteryCollector = batteryCollector ?? BatteryCollector(),
        _locationCollector = locationCollector ?? LocationCollector(),
        _sender = sender ?? Sender(),
        _cleanupJob = cleanupJob ?? CleanupJob(),
        _deviceStateCollector = deviceStateCollector ?? DeviceStateCollector(),
        _diagnostics = diagnostics ?? IotDiagnosticsCollector();

  /// Initialize the manager (called once when background service starts)
  Future<void> initialize() async {
    // Initialize database
    final db = DatabaseFactory.getInstance();
    await db.initialize();

    // Refresh config from SharedPreferences
    await _config.refresh();

    // Initialize cleanup timer to now so it waits the full interval before first run
    // This prevents immediate cleanup on startup which could delete data before it's sent
    _lastCleanup = DateTime.now().millisecondsSinceEpoch;
  }

  /// Run periodic IoT jobs
  /// Should be called on a regular interval (e.g., every 10-30 seconds)
  /// Parameters:
  /// - userId: Current user ID
  /// - runnerStatus: Current runner status (e.g., 'available', 'on_shift')
  /// - iotEndpoint: IoT API endpoint URL
  Future<void> runPeriodicJobs({
    required String userId,
    required String runnerStatus,
    required String iotEndpoint,
  }) async {
    if (_isRunning) return;
    _isRunning = true;
    try {
      // Refresh config to get latest values from SharedPreferences
      try {
        await _config.refresh();
      } catch (e, st) {
        _logger.e('[IoT] Config refresh error', error: e);
        _reportError(e, st, 'IoT config refresh');
        _logDiagnostic(
          userId: userId,
          eventName: 'IOT_CONFIG_REFRESH_ERROR',
          error: e,
        );
        return;
      }

      // Check if IoT API is enabled
      if (!_config.apiEnabled) {
        _logger.d('[IoT] API disabled, skipping jobs');
        return;
      }

      // Refresh app foreground/background state (written by the main isolate)
      // so every diagnostic logged this cycle is stamped with is_fg at emit
      // time — robust to the deferred-flush timestamp distortion.
      await IotDiagnosticsCollector.refreshLifecycleFromPrefs();

      final now = DateTime.now().millisecondsSinceEpoch;

      // Correlation key for this collection cycle. Captured once per tick and
      // passed to every collector that fires below, so the battery, location,
      // and device-state readings collected in this cycle share one id and the
      // backend can group them within a (possibly cached) ping.
      final collectionCycleId = now;

      // Job 1: Battery Collection
      final batteryInterval = _config.batteryCollectionInterval * 1000;
      if (now - _lastBatteryCollection >= batteryInterval) {
        try {
          await _batteryCollector.collect(userId, collectionCycleId: collectionCycleId);
          _lastBatteryCollection = now;
          _logger.d('[IoT] Battery collected');
        } catch (e, st) {
          _logger.e('[IoT] Battery collection error', error: e);
          _reportError(e, st, 'IoT battery collection');
          _logDiagnostic(
            userId: userId,
            eventName: 'IOT_BATTERY_COLLECTION_ERROR',
            error: e,
          );
        }
      } else if (now - _lastBatterySkipLog >= batteryInterval) {
        // Throttled: at most one skip event per battery-interval window.
        _lastBatterySkipLog = now;
        _logDiagnostic(
          userId: userId,
          eventName: 'IOT_BATTERY_COLLECTION_SKIPPED',
          data: {
            'reason': 'interval_not_elapsed',
            'ms_since_last_collection': now - _lastBatteryCollection,
            'interval_ms': batteryInterval,
          },
        );
      }

      // Job 2: Location Collection (interval depends on runner status)
      final locationInterval = _config.getLocationInterval(runnerStatus) * 1000;
      if (now - _lastLocationCollection >= locationInterval) {
        try {
          final locationResult = await _locationCollector.collect(userId, collectionCycleId: collectionCycleId);
          _lastLocationCollection = now;
          if (locationResult < 0 ) {
            _consecutiveLocationFailures++;
            _lastLocationError = _getLocationErrorName(locationResult);
            _logger.d('[IoT] Location skipped: $_lastLocationError');
            _logBreadcrumb('IoT location skipped: $_lastLocationError');
            _logDiagnostic(
              userId: userId,
              eventName: 'IOT_LOCATION_SKIPPED',
              data: {
                'reason': _lastLocationError,
                'consecutive_failures': _consecutiveLocationFailures,
                'runner_status': runnerStatus,
              }
            );
          } else {
            _consecutiveLocationFailures = 0;
            _lastLocationError = '';
          }
        } catch (e, st) {
          _consecutiveLocationFailures++;
          _lastLocationError = e.toString();
          _logger.e('[IoT] Location collection error', error: e);

          _reportError(e, st, 'IoT location collection');

          _logDiagnostic(
              userId: userId,
              eventName: 'IOT_LOCATION_COLLECTION_ERROR',
              error: e,
              data: {
                'consecutive_failures': _consecutiveLocationFailures,
                'runner_status': runnerStatus,
              }
          );
        }

        // Alert on consecutive failures
        if (_consecutiveLocationFailures >= 3 &&
            _consecutiveLocationFailures % 3 == 0) {
          _logDiagnostic(
              userId: userId,
              eventName: 'IOT_LOCATION_CONSECUTIVE_FAILURES',
              data: {
                'failure_count': _consecutiveLocationFailures,
                'last_error': _lastLocationError,
              });

            _reportError(
              Exception('$_consecutiveLocationFailures consecutive location failures'),
              StackTrace.current,
              'IoT location consecutive failures: $_lastLocationError',
            );
        }
      } else if (now - _lastLocationSkipLog >= locationInterval) {
        // Throttled: at most one skip event per location-interval window.
        _lastLocationSkipLog = now;
        _logDiagnostic(
          userId: userId,
          eventName: 'IOT_LOCATION_COLLECTION_SKIPPED',
          data: {
            'reason': 'interval_not_elapsed',
            'ms_since_last_collection': now - _lastLocationCollection,
            'interval_ms': locationInterval,
            'runner_status': runnerStatus,
          },
        );
      }

      // Job 3: Send Data (use battery interval as default send frequency)
      if (now - _lastSendAttempt >= batteryInterval) {
        try {
          final sentCount = await _sender.sendAllData(userId, iotEndpoint);
          if (sentCount > 0) {
            _logger.i('[IoT] Sent $sentCount records');
          }
          _lastSendAttempt = now;
        } catch (e, st) {
          _logger.e('[IoT] Send error', error: e);
          _reportError(e, st, 'IoT send');
          _logDiagnostic(
            eventName: 'IOT_SEND_ERROR',
            userId: userId,
            error: e,
          );
          _lastSendAttempt = now;
        }
      } else if (now - _lastSendSkipLog >= batteryInterval) {
        // Throttled: at most one skip event per send-interval window.
        _lastSendSkipLog = now;
        _logDiagnostic(
          userId: userId,
          eventName: 'IOT_SEND_SKIPPED',
          data: {
            'reason': 'interval_not_elapsed',
            'ms_since_last_attempt': now - _lastSendAttempt,
            'interval_ms': batteryInterval,
          },
        );
      }

      // Job 4: Cleanup (runs every hour)
      final cleanupInterval = _config.cleanupInterval * 1000;
      if (now - _lastCleanup >= cleanupInterval) {
        try {
          final deletedCount = await _cleanupJob.cleanupAllData(userId);
          if (deletedCount > 0) {
            _logger.i('[IoT] Cleanup deleted $deletedCount records');
          }
          _lastCleanup = now;
        } catch (e, st) {
          _logger.e('[IoT] Cleanup error', error: e);
          _reportError(e, st, 'IoT cleanup');
          _logDiagnostic(
            eventName: 'IOT_CLEANUP_ERROR',
            userId: userId,
            error: e,
          );
          _lastCleanup = now;
        }
      }

      // Job 5: Device State Collection
      final deviceStateInterval = _config.deviceStateCollectionInterval * 1000;
      if (now - _lastDeviceStateCollection >= deviceStateInterval) {
        try {
          await _deviceStateCollector.collect(userId, collectionCycleId: collectionCycleId);
          _lastDeviceStateCollection = now;
          _logger.d('[IoT] Device state collected');
        } catch (e, st) {
          _logger.e('[IoT] Device state collection error', error: e);
          _reportError(e, st, 'IoT device state collection');
          _logDiagnostic(
            eventName: 'IOT_DEVICE_STATE_COLLECTION_ERROR',
            userId: userId,
            error: e,
          );
        }
      } else if (now - _lastDeviceStateSkipLog >= deviceStateInterval) {
        // Throttled: at most one skip event per device-state-interval window.
        _lastDeviceStateSkipLog = now;
        _logDiagnostic(
          userId: userId,
          eventName: 'IOT_DEVICE_STATE_COLLECTION_SKIPPED',
          data: {
            'reason': 'interval_not_elapsed',
            'ms_since_last_collection': now - _lastDeviceStateCollection,
            'interval_ms': deviceStateInterval,
          },
        );
      }
    } finally {
      _isRunning = false;
    }
  }

  /// Flush all pending data before shutdown (for kill switch)
  /// Returns true if flush completed successfully
  Future<bool> flush({
    required String userId,
    required String iotEndpoint,
  }) async {
    try {
      // Refresh config
      await _config.refresh();

      if (!_config.apiEnabled) {
        return true; // Nothing to do if IoT is disabled
      }

      // Send all unsent data
      await _sender.sendAllData(userId, iotEndpoint);

      // Cleanup old sent records
      await _cleanupJob.cleanupAllData(userId);

      return true;
    } catch (e) {
      _logger.e('[IoT] Flush error', error: e);
      return false;
    }
  }

  /// Flush and delete all data for user switch (logout/login)
  /// Returns true if completed successfully
  Future<bool> flushAndDeleteAllUserData({
    required String userId,
    required String iotEndpoint,
  }) async {
    try {
      // Refresh config
      await _config.refresh();

      if (!_config.apiEnabled) {
        // Even if IoT is disabled, still delete user data
        await _cleanupJob.deleteAllUserData(userId);
        return true;
      }

      // Try to send all unsent data
      await _sender.sendAllData(userId, iotEndpoint);

      // Delete ALL user data (sent and unsent)
      await _cleanupJob.deleteAllUserData(userId);

      return true;
    } catch (e) {
      _logger.e('[IoT] Flush and delete error', error: e);
      // Even if send fails, still try to delete all data
      try {
        await _cleanupJob.deleteAllUserData(userId);
      } catch (deleteError) {
        _logger.e('[IoT] Delete after flush failed', error: deleteError);
      }
      return false;
    }
  }

  Future<void> _logDiagnostic({
    required String userId,
    required String eventName,
    Object? error,
    Map<String, dynamic>? data,
  }) async {
    Map<String, dynamic> eventData = {
      'memory_rss_mb': IotDiagnosticsCollector.getMemoryRssMb(),
      'user_id': userId,
    };
    if (error != null) {
      eventData.addAll({
        'error_type': error.runtimeType.toString(),
        'error_message': error.toString(),
      });
    }
    if (data != null) {
      eventData.addAll(data);
    }
    await _diagnostics.logDiagnostic(eventName, eventData);
  }

  String _getLocationErrorName(int locationResult) {
    switch (locationResult) {
      case -1:
        return 'location_permission_denied';
      case -2:
        return 'location_collection_timeout';
      case -4:
        return 'location_service_disabled';
      default:
        return 'location_collection_error_thrown';
    }
  }
}
