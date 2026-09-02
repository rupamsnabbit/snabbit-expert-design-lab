import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geolocator/geolocator.dart';
import 'package:snabbit_runner/services/file_ops.dart';
import 'runner_http.dart';
import 'runner_http_wrapper.dart';

/// Testable version of RunnerHttp that accepts dependency wrappers
/// This allows unit testing without changing the existing RunnerHttp class
class RunnerHttpTestable {
  final IHttpServiceWrapper httpService;
  final IGlobalStateWrapper globalState;
  final IGeolocatorWrapper geolocator;
  final IBatteryWrapper battery;

  RunnerHttpTestable({
    required this.httpService,
    required this.globalState,
    required this.geolocator,
    required this.battery,
  });

  /// Testable version of runnerAppCurrentState
  /// Same logic as RunnerHttp.runnerAppCurrentState but with injected dependencies
  Future<Response?> runnerAppCurrentState({
    Map<String, dynamic>? headers,
    bool isFg = true,
    bool skipIotWithRunnerState = false,
  }) async {
    String? batteryLevel;
    bool serviceEnabled;
    LocationPermission permission;
    Position? position;
    double? latitude;
    double? longitude;

    // Skip location/battery fetch when IoT is handling it (recurring background calls)
    if (!skipIotWithRunnerState) {
      try {
        batteryLevel = await battery.getBatteryLevel();
        serviceEnabled = await geolocator.isLocationServiceEnabled();

        if (serviceEnabled) {
          permission = await geolocator.checkPermission();

          if ([LocationPermission.always, LocationPermission.whileInUse]
              .contains(permission)) {
            position = await geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.best,
              timeLimit: Duration(seconds: 45),
            );
            latitude = position.latitude;
            longitude = position.longitude;
          }
        }
      } catch (e) {
        // Match original behavior - swallow errors
      }
    }

    try {
      final url = globalState.serverPath(
        "api/v1/runners/me/app/current_state?lat=$latitude&lng=$longitude&battery=$batteryLevel&is_fg=$isFg",
      );

      final response = await httpService
          .get(url, headers: headers ?? {})
          .timeout(30.seconds, onTimeout: () {
        throw TimeoutException('Request timed out');
      });

      // Note: Removed playSoundOnReceivingNewJob call for simplicity in tests
      // In real implementation, would need to wrap that too
      return response;
    } catch (e) {
      if (isFg) {
        await FileStorage.writeState('stopped');
      }
      return null;
    }
  }
}
