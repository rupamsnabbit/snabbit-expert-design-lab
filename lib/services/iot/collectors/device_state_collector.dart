import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:network_info_plugin/network_info_plugin.dart';
import 'package:snabbit_runner/models/device_state_data.dart';
import 'package:snabbit_runner/services/database/database_factory.dart';
import 'package:snabbit_runner/services/database/database_interface.dart';
import 'package:snabbit_runner/services/iot/diagnostics/iot_diagnostics_collector.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';

/// Interface for checking location service status
abstract class ILocationServiceChecker {
  Future<bool> isLocationServiceEnabled();
}

class GeolocatorLocationServiceChecker implements ILocationServiceChecker {
  @override
  Future<bool> isLocationServiceEnabled() {
    return Geolocator.isLocationServiceEnabled();
  }
}

/// Interface for checking connectivity
abstract class IConnectivityChecker {
  Future<List<ConnectivityResult>> checkConnectivity();
}

class ConnectivityPlusChecker implements IConnectivityChecker {
  @override
  Future<List<ConnectivityResult>> checkConnectivity() {
    return Connectivity().checkConnectivity();
  }
}

/// Interface for getting network type from platform channel
abstract class INetworkTypeProvider {
  Future<String> getNetworkType({void Function(String error)? onError});
}

class PlatformNetworkTypeProvider implements INetworkTypeProvider {
  @override
  Future<String> getNetworkType({void Function(String error)? onError}) =>
      NetworkInfo.getNetworkType(onError: onError);
}

/// Collects device state data and stores it in the database
/// Runs as a background job at configured intervals
class DeviceStateCollector {
  final IDatabaseInterface _db;
  final ILocationServiceChecker _locationServiceChecker;
  final IConnectivityChecker _connectivityChecker;
  final INetworkTypeProvider _networkTypeProvider;
  final IotDiagnosticsCollector _diagnostics;

  DeviceStateCollector({
    IDatabaseInterface? database,
    ILocationServiceChecker? locationServiceChecker,
    IConnectivityChecker? connectivityChecker,
    INetworkTypeProvider? networkTypeProvider,
    IotDiagnosticsCollector? diagnostics,
  })  : _db = database ?? DatabaseFactory.getInstance(),
        _locationServiceChecker = locationServiceChecker ?? GeolocatorLocationServiceChecker(),
        _connectivityChecker = connectivityChecker ?? ConnectivityPlusChecker(),
        _networkTypeProvider = networkTypeProvider ?? PlatformNetworkTypeProvider(),
        _diagnostics = diagnostics ?? IotDiagnosticsCollector();

  /// Collect device state and store in database
  ///
  /// [collectionCycleId] is the id of the background collection cycle this
  /// reading belongs to, shared with the battery/location readings collected
  /// in the same cycle so the backend can correlate them.
  Future<int> collect(String userId, {required int collectionCycleId}) async {
    // 1. Location services
    bool? locationServicesOn;
    try {
      locationServicesOn = await _locationServiceChecker.isLocationServiceEnabled();
    } catch (e) {
      debugPrint('[IoT DeviceState] location services check: $e');
      locationServicesOn = null;
    }

    // 2. Connectivity
    bool? mobileDataOn;
    bool isWifi = false;
    try {
      final results = await _connectivityChecker.checkConnectivity();
      mobileDataOn = results.contains(ConnectivityResult.mobile);
      isWifi = results.contains(ConnectivityResult.wifi);
    } catch (e) {
      debugPrint('[IoT DeviceState] mobile data check: $e');
      mobileDataOn = null;
    }

    // 3. Network type
    String? networkType;
    try {
      if (isWifi) {
        networkType = 'wifi';
      } else if (mobileDataOn == true) {
        networkType = await _networkTypeProvider.getNetworkType(
          onError: (error) => MonitoringServiceHelper.logWarning(
            'network_info_plugin error',
            {'error': error},
          ),
        );
      } else if (mobileDataOn == false) {
        networkType = 'none';
      }
      // if mobileDataOn is null (error), networkType stays null
    } catch (e) {
      debugPrint('[IoT DeviceState] network type check: $e');
      networkType = null;
    }

    _logDiagnostic(
      eventName: 'IOT_DEVICE_STATE_RETRIEVED_SUCCESSFULLY',
      userId: userId,
      data: {
        'location_services_on': locationServicesOn,
        'mobile_data_on': mobileDataOn,
        'network_type': networkType,
        'has_null_fields': locationServicesOn == null || mobileDataOn == null || networkType == null,
      },
    );

    // Insert into database
    final data = DeviceStateData(
      userId: userId,
      locationServicesOn: locationServicesOn,
      mobileDataOn: mobileDataOn,
      networkType: networkType,
      collectedAt: DateTime.now().millisecondsSinceEpoch,
      collectionCycleId: collectionCycleId,
    );

    // Insert may throw; IotBackgroundManager already logs
    // IOT_DEVICE_STATE_COLLECTION_ERROR when it catches the exception.
    // Partial state on failure is still captured by the
    // IOT_DEVICE_STATE_RETRIEVED_SUCCESSFULLY event emitted above.
    final id = await _db.insert(DatabaseTables.deviceState, data.toMap());

    _logDiagnostic(
      eventName: 'IOT_DEVICE_STATE_CACHED_SUCCESSFULLY',
      userId: userId,
      data: {
        'db_row_id': id,
      },
    );

    // Best-effort device "posture" snapshot — emitted as a diagnostic event
    // (JSON eventData, NOT new DB columns) so it ships via a Shorebird patch.
    // Lets us correlate drift with battery-saver / battery-optimization / OEM.
    await _logPosture(userId);

    return id;
  }

  // Cached because manufacturer/model/SDK never change; throttled because
  // posture changes slowly — cuts event volume + per-cycle plugin overhead on
  // the (constrained) bg isolate. Re-emits at the start of each bg session
  // (statics reset on isolate restart) and at most every ~15 min within one.
  static AndroidDeviceInfo? _cachedAndroidInfo;
  static int _lastPostureEmitMs = 0;

  Future<void> _logPosture(String userId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastPostureEmitMs < 15 * 60 * 1000) return;
    try {
      bool? powerSaveMode;
      try {
        powerSaveMode = await Battery().isInBatterySaveMode;
      } catch (_) {}

      bool? batteryOptExempt;
      try {
        batteryOptExempt =
            (await Permission.ignoreBatteryOptimizations.status).isGranted;
      } catch (_) {}

      try {
        if (_cachedAndroidInfo == null &&
            defaultTargetPlatform == TargetPlatform.android) {
          _cachedAndroidInfo = await DeviceInfoPlugin().androidInfo;
        }
      } catch (_) {}

      await _diagnostics.logDiagnostic('IOT_DEVICE_POSTURE', {
        'user_id': userId,
        'power_save_mode': powerSaveMode,
        'battery_opt_exempt': batteryOptExempt,
        'manufacturer': _cachedAndroidInfo?.manufacturer,
        'model': _cachedAndroidInfo?.model,
        'android_sdk_int': _cachedAndroidInfo?.version.sdkInt,
      });
      _lastPostureEmitMs = now;
    } catch (_) {
      // Posture is best-effort; never break device-state collection.
    }
  }

  /// Get count of unsent device state records for a user
  Future<int> getUnsentCount(String userId) async {
    return await _db.count(
      DatabaseTables.deviceState,
      where: 'user_id = ? AND sent = ?',
      whereArgs: [userId, 0],
    );
  }

  /// Get unsent device state records for a user
  Future<List<DeviceStateData>> getUnsent(String userId, {int? limit}) async {
    final results = await _db.query(
      DatabaseTables.deviceState,
      where: 'user_id = ? AND sent = ?',
      whereArgs: [userId, 0],
      orderBy: 'collected_at ASC',
      limit: limit,
    );
    return results.map((map) => DeviceStateData.fromMap(map)).toList();
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
