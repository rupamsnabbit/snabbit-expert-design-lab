import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:snabbit_runner/models/battery_data.dart';
import 'package:snabbit_runner/models/device_state_data.dart';
import 'package:snabbit_runner/models/location_data.dart' as iot_models;
import 'package:snabbit_runner/services/database/database_factory.dart';
import 'package:snabbit_runner/services/database/database_interface.dart';
import 'package:snabbit_runner/services/iot/collectors/battery_collector.dart';
import 'package:snabbit_runner/services/iot/collectors/device_state_collector.dart';
import 'package:snabbit_runner/services/iot/collectors/location_collector.dart';
import 'package:snabbit_runner/services/iot/diagnostics/iot_diagnostics_collector.dart';
import 'package:snabbit_runner/services/iot/http/iot_http.dart';

/// Sends collected IoT data to backend and deletes on success
/// Deletes data immediately after successful API send (post-send cleanup)
class Sender {
  final IDatabaseInterface _db;
  final BatteryCollector _batteryCollector;
  final LocationCollector _locationCollector;
  final DeviceStateCollector _deviceStateCollector;
  final IotHttp _iotHttp;
  final IotDiagnosticsCollector _diagnostics;

  Sender({
    IDatabaseInterface? database,
    BatteryCollector? batteryCollector,
    LocationCollector? locationCollector,
    DeviceStateCollector? deviceStateCollector,
    IotHttp? iotHttp,
    IotDiagnosticsCollector? diagnostics,
  })  : _db = database ?? DatabaseFactory.getInstance(),
        _batteryCollector = batteryCollector ?? BatteryCollector(),
        _locationCollector = locationCollector ?? LocationCollector(),
        _deviceStateCollector = deviceStateCollector ?? DeviceStateCollector(),
        _iotHttp = iotHttp ?? IotHttp(),
        _diagnostics = diagnostics ?? IotDiagnosticsCollector();

  /// Send all unsent data (battery, location, and device state) for user to the IoT API
  /// Deletes records immediately after successful send (post-send cleanup)
  /// Returns total number of records successfully sent
  Future<int> sendAllData(String userId, String endpoint) async {
    try {
      // Get unsent records
      final List<BatteryData> unsentBattery = await _batteryCollector.getUnsent(userId);
      final List<iot_models.LocationData> unsentLocation = await _locationCollector.getUnsent(userId);
      final List<DeviceStateData> unsentDeviceState = await _deviceStateCollector.getUnsent(userId);

      if (unsentBattery.isEmpty && unsentLocation.isEmpty && unsentDeviceState.isEmpty) {
        return 0;
      }

      // Audit location records for zero/suspicious coordinates before sending
      if (unsentLocation.isNotEmpty) {
        final zeroCoordRecords = unsentLocation
            .where((l) => l.lat == 0.0 && l.long == 0.0)
            .toList();
        if (zeroCoordRecords.isNotEmpty) {
          await _diagnostics.logDiagnostic('IOT_LOCATION_NULL_COORDS_IN_SEND_BATCH', {
            'zero_coord_count': zeroCoordRecords.length,
            'total_location_count': unsentLocation.length,
            'zero_coord_collected_at': zeroCoordRecords
                .map((l) => l.collectedAt)
                .toList(),
            'user_id': userId,
          });
        }
      }

      // Convert to maps for API
      final batteryData = unsentBattery.map((record) => record.toMap()).toList();
      final locationData = unsentLocation.map((record) => record.toMap()).toList();
      final deviceStateData = unsentDeviceState.map((record) => record.toMap()).toList();

      // Send to API
      final success = await _iotHttp.sendIotData(
        endpoint: endpoint,
        userId: userId,
        batteries: batteryData,
        locations: locationData,
        deviceStates: deviceStateData,
      );

      if (success) {
        // Delete battery records after successful send (post-send cleanup)
        // id == 0 indicates a record not yet persisted, so skip those
        final batteryIds = unsentBattery
            .where((record) => record.id != 0)
            .map((record) => record.id)
            .toList();

        if (batteryIds.isNotEmpty) {
          final placeholders = List.filled(batteryIds.length, '?').join(',');
          await _db.delete(
            DatabaseTables.battery,
            where: 'id IN ($placeholders)',
            whereArgs: batteryIds,
          );
        }

        // Delete location records after successful send (post-send cleanup)
        // id == 0 indicates a record not yet persisted, so skip those
        final locationIds = unsentLocation
            .where((record) => record.id != 0)
            .map((record) => record.id)
            .toList();

        if (locationIds.isNotEmpty) {
          final placeholders = List.filled(locationIds.length, '?').join(',');
          await _db.delete(
            DatabaseTables.location,
            where: 'id IN ($placeholders)',
            whereArgs: locationIds,
          );
        }

        // Delete device state records after successful send
        final deviceStateIds = unsentDeviceState
            .where((record) => record.id != 0)
            .map((record) => record.id)
            .toList();

        if (deviceStateIds.isNotEmpty) {
          final placeholders = List.filled(deviceStateIds.length, '?').join(',');
          await _db.delete(
            DatabaseTables.deviceState,
            where: 'id IN ($placeholders)',
            whereArgs: deviceStateIds,
          );
        }

        return unsentBattery.length + unsentLocation.length + unsentDeviceState.length;
      }

      // API call failed, records remain for retry
      return 0;
    } catch (e) {
      _reportNonFatal(e, StackTrace.current, 'IoT sendAllData failed');
      return 0;
    }
  }

  static void _reportNonFatal(Object error, StackTrace st, String reason) {
    FirebaseCrashlytics.instance.recordError(error, st, reason: reason, fatal: false);
  }
}
