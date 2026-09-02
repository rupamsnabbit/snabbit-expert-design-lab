import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:geolocator/geolocator.dart';
import 'package:snabbit_runner/models/location_data.dart' as iot_models;
import 'package:snabbit_runner/services/database/database_factory.dart';
import 'package:snabbit_runner/services/database/database_interface.dart';
import 'package:snabbit_runner/services/iot/collectors/device_state_collector.dart';
import 'package:snabbit_runner/services/iot/diagnostics/iot_diagnostics_collector.dart';


/// Interface for location provider to enable testing
abstract class ILocationProvider {
  Future<Position> getCurrentPosition();
}

/// Default implementation using Geolocator
class GeolocatorLocationProvider implements ILocationProvider {
  @override
  Future<Position> getCurrentPosition() {
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 30),
      ),
    );
  }
}

/// Interface for checking location permission status
abstract class ILocationPermissionChecker {
  Future<LocationPermission> checkPermission();
}

class GeolocatorPermissionChecker implements ILocationPermissionChecker {
  @override
  Future<LocationPermission> checkPermission() {
    return Geolocator.checkPermission();
  }
}

/// Collects GPS location data and stores it in the database
/// Runs as a background job at configured intervals based on runner status
/// Uses geolocator package which works properly in background isolates
class LocationCollector {
  final IDatabaseInterface _db;
  final ILocationProvider _locationProvider;
  final ILocationServiceChecker _locationServiceChecker;
  final ILocationPermissionChecker _permissionChecker;
  final IotDiagnosticsCollector _diagnostics;


  LocationCollector({
    IDatabaseInterface? database,
    ILocationProvider? locationProvider,
    ILocationServiceChecker? locationServiceChecker,
    ILocationPermissionChecker? permissionChecker,
    IotDiagnosticsCollector? diagnostics,
  })  : _db = database ?? DatabaseFactory.getInstance(),
        _locationProvider = locationProvider ?? GeolocatorLocationProvider(),
        _locationServiceChecker = locationServiceChecker ?? GeolocatorLocationServiceChecker(),
        _permissionChecker = permissionChecker ?? GeolocatorPermissionChecker(),
        _diagnostics = diagnostics ?? IotDiagnosticsCollector();

  /// Collect current location and store in database
  /// Returns the row ID of the inserted record, or -1 if location services are off
  ///
  /// [collectionCycleId] is the id of the background collection cycle this
  /// reading belongs to, shared with the battery/device-state readings
  /// collected in the same cycle so the backend can correlate them.
  Future<int> collect(String userId, {required int collectionCycleId}) async {
    final memoryRssMb = IotDiagnosticsCollector.getMemoryRssMb();

    // Check memory pressure
    if (memoryRssMb > 200) {
      _logDiagnostic(eventName: 'IOT_MEMORY_PRESSURE', userId: userId, data: {
        'memory_rss_mb': memoryRssMb,
        'phase': 'location_collection_start',
      });
    }

    // Check runtime permission status
    LocationPermission? permission;
    try {
      permission = await _permissionChecker.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _logDiagnostic(
            eventName: 'IOT_LOCATION_PERMISSION_DENIED',
            userId: userId,
            data: {
              'permission_status': permission.name,
            });
        return -1;
      }
      // Background collection needs "Allow all the time" (always). whileInUse
      // only delivers fixes while the app is foregrounded, so a runner with
      // whileInUse silently stops producing background locations. Record it so
      // it's distinguishable from a healthy "always" grant (we still attempt
      // the fix below, since it succeeds while foregrounded).
      if (permission == LocationPermission.whileInUse) {
        _logDiagnostic(
            eventName: 'IOT_LOCATION_WHILE_IN_USE_ONLY',
            userId: userId,
            data: {
              'permission_status': permission.name,
            });
      }
    } catch (e,st) {
      final event = 'IOT_LOCATION_PERMISSION_CHECK_ERROR';
      _logDiagnostic(
        eventName: event,
        userId: userId,
        data: {
          'error_type': e.runtimeType.toString(),
          'error_message': e.toString(),
        },
      );
      FirebaseCrashlytics.instance.recordError(
        e,
        st,
        reason: event,
      );
    }

    // Check if location services are enabled
    try {
      final isLocationEnabled = await _locationServiceChecker.isLocationServiceEnabled();
      if (!isLocationEnabled) {
        _logDiagnostic(
          eventName: 'IOT_LOCATION_SERVICE_DISABLED',
          userId: userId,
        );
        return -4;
      }
    } catch (e,st) {
      final event = 'IOT_LOCATION_SERVICE_CHECK_ERROR';
      await _diagnostics.logDiagnostic(event, {
        'error_type': e.runtimeType.toString(),
        'error_message': e.toString(),
        'user_id': userId,
      });
      FirebaseCrashlytics.instance.recordError(
        e,
        st,
        reason: event,
      );
    }

    // Collect location with timing
    int id;
    final stopwatch = Stopwatch()..start();
    try {
      final locationData = await _locationProvider.getCurrentPosition();

      _logDiagnostic(
          eventName: 'IOT_LOCATION_RETRIEVED_SUCCESSFULLY',
          userId: userId,
          data: {
            'lat': locationData.latitude,
            'long': locationData.longitude,
            'accuracy': locationData.accuracy,
            // Spot devices stuck on coarse/network-only fixes (battery-saving
            // location mode) and stale cached fixes reported as current.
            'accuracy_bucket': _accuracyBucket(locationData.accuracy),
            'fix_staleness_ms': DateTime.now().millisecondsSinceEpoch -
                locationData.timestamp.millisecondsSinceEpoch,
            'is_mocked': locationData.isMocked,
            'duration_ms': stopwatch.elapsedMilliseconds,
          });


      // Detect zero/null coordinates
      if (locationData.latitude == 0.0 && locationData.longitude == 0.0) {
        _logDiagnostic(
            eventName: 'IOT_LOCATION_ZERO_COORDINATES',
            userId: userId,
            data: {
              'lat': locationData.latitude,
              'long': locationData.longitude,
              'accuracy': locationData.accuracy,
              'is_mocked': locationData.isMocked,
              'duration_ms': stopwatch.elapsedMilliseconds,
            });
      }

      final iotLocationData = iot_models.LocationData(
        userId: userId,
        lat: locationData.latitude,
        long: locationData.longitude,
        accuracy: locationData.accuracy,
        alt: locationData.altitude,
        altAccuracy: locationData.altitudeAccuracy,
        heading: locationData.heading,
        headingAccuracy: locationData.headingAccuracy,
        speed: locationData.speed,
        speedAccuracy: locationData.speedAccuracy,
        isMocked: locationData.isMocked,
        collectedAt: locationData.timestamp.millisecondsSinceEpoch,
        collectionCycleId: collectionCycleId,
      );

      id = await _db.insert(
        DatabaseTables.location,
        iotLocationData.toMap(),
      );

      _logDiagnostic(
          eventName: 'IOT_LOCATION_CACHED_SUCCESSFULLY',
          userId: userId,
          data: {
            'lat': locationData.latitude,
            'long': locationData.longitude,
            'accuracy': locationData.accuracy,
            'is_mocked': locationData.isMocked,
            'duration_ms': stopwatch.elapsedMilliseconds,
          });
    } on TimeoutException catch (e,st) {
      final event = 'IOT_LOCATION_COLLECTION_TIMEOUT';
      _logDiagnostic(
          eventName: event,
          userId: userId,
          data: {
            'timeout_seconds': e.duration?.inSeconds ?? 0,
            'duration_ms': stopwatch.elapsedMilliseconds,
            'error_message': e.toString(),
          });
      id = -2;
      FirebaseCrashlytics.instance.recordError(
        e,
        st,
        reason: event,
      );
    } catch (e,st) {
      final event = 'IOT_LOCATION_COLLECTION_ERROR';
      _logDiagnostic(
          eventName: event,
          userId: userId,
          data: {
            'error_kind': _classifyGeolocatorError(e),
            'permission_status': permission?.name,
            'error_type': e.runtimeType.toString(),
            'error_message': e.toString(),
            'stack_trace':
            StackTrace.current.toString().split('\n').take(10).join('\n'),
            'duration_ms': stopwatch.elapsedMilliseconds,
          });
      id = -3;
      FirebaseCrashlytics.instance.recordError(
        e,
        st,
        reason: event,
      );
    }
    stopwatch.stop();
    return id;
  }


  Future<int> getUnsentCount(String userId) async {
    return await _db.count(
      DatabaseTables.location,
      where: 'user_id = ? AND sent = ?',
      whereArgs: [userId, 0],
    );
  }

  /// Get unsent location records for a user
  Future<List<iot_models.LocationData>> getUnsent(String userId,
      {int? limit}) async {
    final results = await _db.query(
      DatabaseTables.location,
      where: 'user_id = ? AND sent = ?',
      whereArgs: [userId, 0],
      orderBy: 'collected_at ASC',
      limit: limit,
    );

    return results.map((map) => iot_models.LocationData.fromMap(map)).toList();
  }

  /// Returns the most recent location for [userId] if collected within [maxAgeSeconds].
  /// Used by current_state to avoid blocking on GPS when a recent cached location exists.
  Future<iot_models.LocationData?> getLastCollected(String userId,
      {int maxAgeSeconds = 60}) async {
    final results = await _db.query(
      DatabaseTables.location,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'collected_at DESC',
      limit: 1,
    );
    if (results.isEmpty) return null;
    final row = results.first;
    final collectedAt = row['collected_at'] as int;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - collectedAt > maxAgeSeconds * 1000) return null;
    return iot_models.LocationData.fromMap(row);
  }


  /// Normalizes a Geolocator failure into a stable, queryable kind so
  /// dashboards/alerts don't have to parse platform error strings (which vary
  /// by OS/OEM). e.g. distinguishes "service disabled at fix time" (common on
  /// battery-saving location mode) from a permission or generic failure.
  String _classifyGeolocatorError(Object e) {
    if (e is LocationServiceDisabledException) {
      return 'location_service_disabled';
    }
    if (e is PermissionDeniedException) return 'permission_denied';
    if (e is PermissionDefinitionsNotFoundException) {
      return 'permission_definitions_not_found';
    }
    if (e is PositionUpdateException) return 'position_update_failed';
    if (e is TimeoutException) return 'timeout';
    return 'unknown';
  }

  /// Buckets GPS accuracy (metres) so we can spot devices stuck returning
  /// coarse/network-only fixes (e.g. battery-saving location mode).
  String _accuracyBucket(double accuracy) {
    if (accuracy <= 20) return 'fine';
    if (accuracy <= 100) return 'coarse';
    return 'very_coarse';
  }

  Future<void> _logDiagnostic({
    required String userId,
    required String eventName,
    Map<String, dynamic>? data,
  }) async {
    Map<String, dynamic> eventData = {
      'memory_rss_mb': IotDiagnosticsCollector.getMemoryRssMb(),
      'user_id': userId,
    };
    if (data != null) {
      eventData.addAll(data);
    }
    await _diagnostics.logDiagnostic(eventName, eventData);
  }

}
