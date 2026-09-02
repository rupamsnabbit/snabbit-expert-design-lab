import 'package:geolocator/geolocator.dart';
import 'package:snabbit_runner/services/runner_http_wrapper.dart';

/// Testable version of fetchCurrentLocation from common_methods.dart
/// Uses dependency injection to allow mocking Geolocator
class CommonMethodsTestable {
  final IGeolocatorWrapper geolocator;

  CommonMethodsTestable({required this.geolocator});

  /// Testable version of fetchCurrentLocation
  /// Same logic as common_methods.dart but with injected geolocator dependency
  Future<Position?> fetchCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;
    Position position;

    try {
      serviceEnabled = await geolocator.isLocationServiceEnabled();

      if (serviceEnabled) {
        permission = await geolocator.checkPermission();

        if ([LocationPermission.always, LocationPermission.whileInUse]
            .contains(permission)) {
          position = await geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.best,
            timeLimit: const Duration(seconds: 5),
          );

          return position;
        }
      }
    } catch (e) {
      return null;
    }
    return null;
  }
}
