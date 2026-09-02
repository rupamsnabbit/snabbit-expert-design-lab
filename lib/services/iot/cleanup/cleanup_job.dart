import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:logger/logger.dart';
import 'package:snabbit_runner/services/database/database_factory.dart';
import 'package:snabbit_runner/services/database/database_interface.dart';
import 'package:snabbit_runner/services/iot/config/config_service.dart';
import 'package:snabbit_runner/services/iot/diagnostics/iot_diagnostics_reporter.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';

/// Cleans up IoT data to prevent database bloat
///
/// Two cleanup strategies:
/// 1. Post-send cleanup: Delete successfully sent records (after API success)
/// 2. Periodic cleanup: Enforce max limits using FIFO (delete oldest first)
///    regardless of sent status - for offline/network failure scenarios
class CleanupJob {
  final IDatabaseInterface _db;
  final ConfigService _config;
  final Logger _logger = Logger();

  CleanupJob({
    IDatabaseInterface? database,
    ConfigService? config,
  })  : _db = database ?? DatabaseFactory.getInstance(),
        _config = config ?? ConfigService.instance;

  // ==========================================================================
  // POST-SEND CLEANUP: Delete successfully sent records
  // ==========================================================================

  /// Delete all sent battery records for a user
  /// Called after successful API send to free up space
  Future<int> cleanupSentBatteryData(String userId) async {
    try {
      final deletedCount = await _db.delete(
        DatabaseTables.battery,
        where: 'user_id = ? AND sent = ?',
        whereArgs: [userId, 1],
      );
      return deletedCount;
    } catch (e) {
      _logger.e('[IoT Cleanup] cleanupSentBatteryData error', error: e);
      return 0;
    }
  }

  /// Delete all sent location records for a user
  /// Called after successful API send to free up space
  Future<int> cleanupSentLocationData(String userId) async {
    try {
      final deletedCount = await _db.delete(
        DatabaseTables.location,
        where: 'user_id = ? AND sent = ?',
        whereArgs: [userId, 1],
      );
      return deletedCount;
    } catch (e) {
      _logger.e('[IoT Cleanup] cleanupSentLocationData error', error: e);
      return 0;
    }
  }

  /// Delete all sent device state records for a user
  /// Called after successful API send to free up space
  Future<int> cleanupSentDeviceStateData(String userId) async {
    try {
      final deletedCount = await _db.delete(
        DatabaseTables.deviceState,
        where: 'user_id = ? AND sent = ?',
        whereArgs: [userId, 1],
      );
      return deletedCount;
    } catch (e) {
      _logger.e('[IoT Cleanup] cleanupSentDeviceStateData error', error: e);
      return 0;
    }
  }

  /// Cleanup all sent data (battery, location, and device state) for a user
  /// Called after successful API send
  Future<int> cleanupSentData(String userId) async {
    final batteryDeleted = await cleanupSentBatteryData(userId);
    final locationDeleted = await cleanupSentLocationData(userId);
    final deviceStateDeleted = await cleanupSentDeviceStateData(userId);
    return batteryDeleted + locationDeleted + deviceStateDeleted;
  }

  // ==========================================================================
  // PERIODIC CLEANUP: Enforce max limits using FIFO (oldest first)
  // ==========================================================================

  /// Enforce max battery records limit using FIFO (delete oldest first)
  /// Runs periodically (hourly) to prevent DB bloat during offline/network failure
  /// Deletes oldest records regardless of sent status
  Future<int> cleanupBatteryData(String userId) async {
    try {
      final maxRecords = _config.maxBatteryRecords;

      // Count total records for user
      final totalCount = await _db.count(
        DatabaseTables.battery,
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      _logger.d('[IoT Cleanup] Battery: total=$totalCount, max=$maxRecords');

      if (totalCount <= maxRecords) {
        return 0; // No cleanup needed
      }

      // Delete oldest records exceeding the limit (FIFO)
      final recordsToDelete = totalCount - maxRecords;
      _logger.i('[IoT Cleanup] Battery FIFO: deleting $recordsToDelete oldest records');

      await _db.execute('''
        DELETE FROM ${DatabaseTables.battery}
        WHERE id IN (
          SELECT id FROM ${DatabaseTables.battery}
          WHERE user_id = ?
          ORDER BY collected_at ASC
          LIMIT ?
        )
      ''', [userId, recordsToDelete]);

      return recordsToDelete;
    } catch (e) {
      _logger.e('[IoT Cleanup] Battery cleanup error: $e');
      return 0;
    }
  }

  /// Enforce max location records limit using FIFO (delete oldest first)
  /// Runs periodically (hourly) to prevent DB bloat during offline/network failure
  /// Deletes oldest records regardless of sent status
  Future<int> cleanupLocationData(String userId) async {
    try {
      final maxRecords = _config.maxLocationRecords;

      // Count total records for user
      final totalCount = await _db.count(
        DatabaseTables.location,
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      _logger.d('[IoT Cleanup] Location: total=$totalCount, max=$maxRecords');

      if (totalCount <= maxRecords) {
        return 0; // No cleanup needed
      }

      // Delete oldest records exceeding the limit (FIFO)
      final recordsToDelete = totalCount - maxRecords;
      _logger.i('[IoT Cleanup] Location FIFO: deleting $recordsToDelete oldest records');

      await _db.execute('''
        DELETE FROM ${DatabaseTables.location}
        WHERE id IN (
          SELECT id FROM ${DatabaseTables.location}
          WHERE user_id = ?
          ORDER BY collected_at ASC
          LIMIT ?
        )
      ''', [userId, recordsToDelete]);

      return recordsToDelete;
    } catch (e) {
      _logger.e('[IoT Cleanup] Location cleanup error: $e');
      return 0;
    }
  }

  /// Enforce max device state records limit using FIFO (delete oldest first)
  /// Runs periodically (hourly) to prevent DB bloat during offline/network failure
  /// Deletes oldest records regardless of sent status
  Future<int> cleanupDeviceStateData(String userId) async {
    try {
      final maxRecords = _config.maxDeviceStateRecords;

      // Count total records for user
      final totalCount = await _db.count(
        DatabaseTables.deviceState,
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      _logger.d('[IoT Cleanup] DeviceState: total=$totalCount, max=$maxRecords');

      if (totalCount <= maxRecords) {
        return 0; // No cleanup needed
      }

      // Delete oldest records exceeding the limit (FIFO)
      final recordsToDelete = totalCount - maxRecords;
      _logger.i('[IoT Cleanup] DeviceState FIFO: deleting $recordsToDelete oldest records');

      await _db.execute('''
        DELETE FROM ${DatabaseTables.deviceState}
        WHERE id IN (
          SELECT id FROM ${DatabaseTables.deviceState}
          WHERE user_id = ?
          ORDER BY collected_at ASC
          LIMIT ?
        )
      ''', [userId, recordsToDelete]);

      return recordsToDelete;
    } catch (e) {
      _logger.e('[IoT Cleanup] DeviceState cleanup error: $e');
      return 0;
    }
  }

  /// Enforce max limits for all data (battery, location, and device state) for a user
  /// Called periodically (hourly) to prevent DB bloat
  /// Returns total number of records deleted
  Future<int> cleanupAllData(String userId) async {
    final batteryDeleted = await cleanupBatteryData(userId);
    final locationDeleted = await cleanupLocationData(userId);
    final deviceStateDeleted = await cleanupDeviceStateData(userId);

    // Cleanup old diagnostic events (older than 24 hours)
    try {
      final diagnosticsReporter = IotDiagnosticsReporter(database: _db);
      await diagnosticsReporter.cleanupOldEvents();
    } catch (e,st) {
      _logger.e('[IoT Cleanup] Diagnostic events cleanup error', error: e);
      MonitoringServiceHelper.logError(
        "DIAGNOSTICS_EVENTS_CLEANUP_ERROR",
        {
          "error": e.toString(),
          "stacktrace": st.toString(),
        },
      );

      FirebaseCrashlytics.instance.recordError(e, st);
    }

    return batteryDeleted + locationDeleted + deviceStateDeleted;
  }

  // ==========================================================================
  // USER DATA DELETION: For logout/user switch
  // ==========================================================================

  /// Delete ALL data for a user (for logout/user switch)
  /// This is more aggressive than regular cleanup
  Future<int> deleteAllUserData(String userId) async {
    try {
      final batteryDeleted = await _db.delete(
        DatabaseTables.battery,
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      final locationDeleted = await _db.delete(
        DatabaseTables.location,
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      final deviceStateDeleted = await _db.delete(
        DatabaseTables.deviceState,
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      return batteryDeleted + locationDeleted + deviceStateDeleted;
    } catch (e) {
      // Don't throw - allow caller to handle
      _logger.e('[IoT Cleanup] deleteAllUserData error', error: e);
      return 0;
    }
  }
}
