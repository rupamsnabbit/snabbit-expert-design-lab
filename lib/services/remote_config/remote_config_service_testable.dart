import 'remote_config_wrapper.dart';

/// Testable version of RemoteConfigService that accepts dependency wrapper
/// This allows unit testing without changing the existing RemoteConfigService class
class RemoteConfigServiceTestable {
  final IRemoteConfigWrapper config;

  RemoteConfigServiceTestable({required this.config});

  /// Testable version of getInt
  /// Same logic as RemoteConfigService.getInt but with injected config dependency
  int getInt(String key, {int defaultValue = 0}) {
    try {
      return config.getInt(key) ?? defaultValue;
    } catch (e) {
      return defaultValue;
    }
  }

  /// Testable version of getBool
  /// Same logic as RemoteConfigService.getBool but with injected config dependency
  bool getBool(String key, {bool defaultValue = false}) {
    try {
      return config.getBool(key) ?? defaultValue;
    } catch (e) {
      return defaultValue;
    }
  }

  /// Testable version of getString
  /// Same logic as RemoteConfigService.getString but with injected config dependency
  String getString(String key, {String defaultValue = ''}) {
    try {
      return config.getString(key) ?? defaultValue;
    } catch (e) {
      return defaultValue;
    }
  }

  /// Testable version of getDouble
  /// Same logic as RemoteConfigService.getDouble but with injected config dependency
  double getDouble(String key, {double defaultValue = 0.0}) {
    try {
      return config.getDouble(key) ?? defaultValue;
    } catch (e) {
      return defaultValue;
    }
  }
}
