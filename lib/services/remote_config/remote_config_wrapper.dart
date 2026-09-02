import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'remote_config_service.dart';

/// Wrapper around FirebaseRemoteConfig to enable unit testing
abstract class IRemoteConfigWrapper {
  int? getInt(String key);
  bool? getBool(String key);
  String? getString(String key);
  double? getDouble(String key);
}

/// Production implementation that delegates to FirebaseRemoteConfig
class RemoteConfigWrapper implements IRemoteConfigWrapper {
  final FirebaseRemoteConfig? _config;

  RemoteConfigWrapper(this._config);

  @override
  int? getInt(String key) {
    return _config?.getInt(key);
  }

  @override
  bool? getBool(String key) {
    return _config?.getBool(key);
  }

  @override
  String? getString(String key) {
    return _config?.getString(key);
  }

  @override
  double? getDouble(String key) {
    return _config?.getDouble(key);
  }
}
