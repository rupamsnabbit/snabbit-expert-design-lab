import 'package:battery_plus/battery_plus.dart';
import 'package:snabbit_runner/models/battery_data.dart';
import 'package:snabbit_runner/services/database/database_factory.dart';
import 'package:snabbit_runner/services/database/database_interface.dart';
import 'package:snabbit_runner/services/iot/diagnostics/iot_diagnostics_collector.dart';

/// Collects battery percentage data and stores it in the database
/// Runs as a background job at configured intervals
class BatteryCollector {
  final IDatabaseInterface _db;
  final Battery _battery;
  final IotDiagnosticsCollector _diagnostics;

  BatteryCollector({
    IDatabaseInterface? database,
    Battery? battery,
    IotDiagnosticsCollector? diagnostics,
  })  : _db = database ?? DatabaseFactory.getInstance(),
        _battery = battery ?? Battery(),
        _diagnostics = diagnostics ?? IotDiagnosticsCollector();

  /// Collect current battery percentage and store in database
  /// Returns the row ID of the inserted record
  ///
  /// [collectionCycleId] is the id of the background collection cycle this
  /// reading belongs to, shared with the location/device-state readings
  /// collected in the same cycle so the backend can correlate them.
  Future<int> collect(String userId, {required int collectionCycleId}) async {
    try {
      // Get current battery level
      final batteryLevel = await _battery.batteryLevel;

      _logDiagnostic(
        eventName: 'IOT_BATTERY_RETRIEVED_SUCCESSFULLY',
        userId: userId,
        data: {
          'percentage': batteryLevel,
        },
      );

      // Create battery data model
      final batteryData = BatteryData(
        userId: userId,
        percentage: batteryLevel,
        collectedAt: DateTime.now().millisecondsSinceEpoch,
        collectionCycleId: collectionCycleId,
      );

      // Insert into database
      final id = await _db.insert(
        DatabaseTables.battery,
        batteryData.toMap(),
      );

      _logDiagnostic(
        eventName: 'IOT_BATTERY_CACHED_SUCCESSFULLY',
        userId: userId,
        data: {
          'percentage': batteryLevel,
          'db_row_id': id,
        },
      );

      return id;
    } catch (e) {
      // Re-throw with context; IotBackgroundManager already logs
      // IOT_BATTERY_COLLECTION_ERROR when it catches this.
      throw Exception('Failed to collect battery data: $e');
    }
  }

  /// Get count of unsent battery records for a user
  Future<int> getUnsentCount(String userId) async {
    return await _db.count(
      DatabaseTables.battery,
      where: 'user_id = ? AND sent = ?',
      whereArgs: [userId, 0],
    );
  }

  /// Get unsent battery records for a user
  Future<List<BatteryData>> getUnsent(String userId, {int? limit}) async {
    final results = await _db.query(
      DatabaseTables.battery,
      where: 'user_id = ? AND sent = ?',
      whereArgs: [userId, 0],
      orderBy: 'collected_at ASC',
      limit: limit,
    );

    return results.map((map) => BatteryData.fromMap(map)).toList();
  }

  Future<void> _logDiagnostic({
    required String userId,
    required String eventName,
    Map<String, dynamic>? data,
  }) async {
    Map<String, dynamic> eventData = {
      'user_id': userId,
    };
    if (data != null) {
      eventData.addAll(data);
    }
    await _diagnostics.logDiagnostic(eventName, eventData);
  }
}
