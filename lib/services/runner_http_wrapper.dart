import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/common_methods.dart' as common_methods;
import 'globals.dart';
import 'http_service.dart';

/// Wrapper around static dependencies to make RunnerHttp testable
/// This allows us to inject mock implementations in tests without refactoring existing code
abstract class IHttpServiceWrapper {
  Future<Response> get(String url, {Map<String, dynamic>? headers});
}

abstract class IGlobalStateWrapper {
  String serverPath(String path);
}

abstract class IGeolocatorWrapper {
  Future<bool> isLocationServiceEnabled();
  Future<LocationPermission> checkPermission();
  Future<Position> getCurrentPosition({
    LocationAccuracy? desiredAccuracy,
    Duration? timeLimit,
  });
}

abstract class IBatteryWrapper {
  Future<String?> getBatteryLevel();
}

/// Production implementations (delegates to real singletons)
class HttpServiceWrapper implements IHttpServiceWrapper {
  @override
  Future<Response> get(String url, {Map<String, dynamic>? headers}) {
    return HttpService().get(url, headers: headers ?? {});
  }
}

class GlobalStateWrapper implements IGlobalStateWrapper {
  @override
  String serverPath(String path) {
    return GlobalState().serverPath(path);
  }
}

class GeolocatorWrapper implements IGeolocatorWrapper {
  @override
  Future<bool> isLocationServiceEnabled() {
    return Geolocator.isLocationServiceEnabled();
  }

  @override
  Future<LocationPermission> checkPermission() {
    return Geolocator.checkPermission();
  }

  @override
  Future<Position> getCurrentPosition({
    LocationAccuracy? desiredAccuracy,
    Duration? timeLimit,
  }) {
    return Geolocator.getCurrentPosition(
      desiredAccuracy: desiredAccuracy ?? LocationAccuracy.best,
      timeLimit: timeLimit,
    );
  }
}

class BatteryWrapper implements IBatteryWrapper {
  @override
  Future<String?> getBatteryLevel() {
    return common_methods.getBatteryLevel();
  }
}
