import 'package:shared_preferences/shared_preferences.dart';
import 'config_defaults.dart';

/// IoT Configuration Service for background thread
/// Reads from SharedPreferences (synced by ConfigSync) into memory cache
/// Singleton per isolate
class ConfigService {
  static ConfigService? _instance;

  // Memory cache for fast reads
  final Map<String, dynamic> _cache = {};
  bool _isInitialized = false;

  ConfigService._internal();

  /// Get singleton instance
  static ConfigService get instance {
    _instance ??= ConfigService._internal();
    return _instance!;
  }

  /// Initialize by loading config from SharedPreferences into memory cache
  Future<void> initialize() async {
    if (_isInitialized) return;

    await refresh();
    _isInitialized = true;
  }

  /// Refresh cache from SharedPreferences
  /// Call this when receiving "config_updated" signal from foreground
  Future<void> refresh() async {
    final prefs = await SharedPreferences.getInstance();

    // Load all IoT config into cache with individual defaults
    _cache['apiEnabled'] = prefs.getBool('iot_config_api_enabled') ??
        ConfigDefaults.apiEnabled;

    _cache['batteryCollectionInterval'] =
        prefs.getInt('iot_config_battery_collection_interval_seconds') ??
            ConfigDefaults.batteryCollectionInterval;

    _cache['locationIntervalIdle'] =
        prefs.getInt('iot_config_location_interval_idle') ??
            ConfigDefaults.locationIntervalIdle;

    _cache['locationIntervalAssigned'] =
        prefs.getInt('iot_config_location_interval_assigned') ??
            ConfigDefaults.locationIntervalAssigned;

    _cache['locationIntervalInTransit'] =
        prefs.getInt('iot_config_location_interval_in_transit') ??
            ConfigDefaults.locationIntervalInTransit;

    _cache['locationIntervalOnJob'] =
        prefs.getInt('iot_config_location_interval_on_job') ??
            ConfigDefaults.locationIntervalOnJob;

    _cache['locationIntervalOffline'] =
        prefs.getInt('iot_config_location_interval_offline') ??
            ConfigDefaults.locationIntervalOffline;

    _cache['locationIntervalDefault'] =
        prefs.getInt('iot_config_location_interval_default') ??
            ConfigDefaults.locationIntervalDefault;

    _cache['sendInterval'] =
        prefs.getInt('iot_config_send_interval_seconds') ??
            ConfigDefaults.sendInterval;

    _cache['maxBatteryRecords'] =
        prefs.getInt('iot_config_max_battery_records') ??
            ConfigDefaults.maxBatteryRecords;

    _cache['maxLocationRecords'] =
        prefs.getInt('iot_config_max_location_records') ??
            ConfigDefaults.maxLocationRecords;

    _cache['deviceStateCollectionInterval'] =
        prefs.getInt('iot_config_device_state_collection_interval_seconds') ??
            ConfigDefaults.deviceStateCollectionInterval;

    _cache['maxDeviceStateRecords'] =
        prefs.getInt('iot_config_max_device_state_records') ??
            ConfigDefaults.maxDeviceStateRecords;

    _cache['apiTimeout'] =
        prefs.getInt('iot_config_api_timeout_seconds') ??
            ConfigDefaults.apiTimeout;

    _cache['cleanupInterval'] =
        prefs.getInt('iot_config_cleanup_interval_seconds') ??
            ConfigDefaults.cleanupInterval;

    _cache['killSwitchMaxWait'] =
        prefs.getInt('iot_config_kill_switch_max_wait_seconds') ??
            ConfigDefaults.killSwitchMaxWait;

    _cache['fgFallbackEnabled'] =
        prefs.getBool('iot_config_fg_fallback_enabled') ??
            ConfigDefaults.fgFallbackEnabled;

    _cache['fgFallbackStalenessThresholdSeconds'] =
        prefs.getInt('iot_config_fg_fallback_staleness_threshold_seconds') ??
            ConfigDefaults.fgFallbackStalenessThresholdSeconds;
  }

  /// Get feature flag enabled status
  bool get apiEnabled => _cache['apiEnabled'] ?? ConfigDefaults.apiEnabled;

  /// Get battery collection interval (seconds)
  int get batteryCollectionInterval =>
      _cache['batteryCollectionInterval'] ??
      ConfigDefaults.batteryCollectionInterval;

  /// Get location interval for runner status
  int getLocationInterval(String status) {
    switch (status.toLowerCase()) {
      case 'idle':
        return _cache['locationIntervalIdle'] ??
            ConfigDefaults.locationIntervalIdle;
      case 'assigned':
        return _cache['locationIntervalAssigned'] ??
            ConfigDefaults.locationIntervalAssigned;
      case 'in_transit':
        return _cache['locationIntervalInTransit'] ??
            ConfigDefaults.locationIntervalInTransit;
      case 'on_job':
        return _cache['locationIntervalOnJob'] ??
            ConfigDefaults.locationIntervalOnJob;
      case 'offline':
        return _cache['locationIntervalOffline'] ??
            ConfigDefaults.locationIntervalOffline;
      default:
        return _cache['locationIntervalDefault'] ??
            ConfigDefaults.locationIntervalDefault;
    }
  }

  /// Get send interval (seconds)
  int get sendInterval =>
      _cache['sendInterval'] ?? ConfigDefaults.sendInterval;

  /// Get max battery records limit
  int get maxBatteryRecords =>
      _cache['maxBatteryRecords'] ?? ConfigDefaults.maxBatteryRecords;

  /// Get max location records limit
  int get maxLocationRecords =>
      _cache['maxLocationRecords'] ?? ConfigDefaults.maxLocationRecords;

  /// Get device state collection interval (seconds)
  int get deviceStateCollectionInterval =>
      _cache['deviceStateCollectionInterval'] ??
      ConfigDefaults.deviceStateCollectionInterval;

  /// Get max device state records limit
  int get maxDeviceStateRecords =>
      _cache['maxDeviceStateRecords'] ?? ConfigDefaults.maxDeviceStateRecords;

  /// Get API timeout (seconds)
  int get apiTimeout =>
      _cache['apiTimeout'] ?? ConfigDefaults.apiTimeout;

  /// Get cleanup interval (seconds)
  int get cleanupInterval =>
      _cache['cleanupInterval'] ?? ConfigDefaults.cleanupInterval;

  /// Get kill switch max wait (seconds)
  int get killSwitchMaxWait =>
      _cache['killSwitchMaxWait'] ?? ConfigDefaults.killSwitchMaxWait;

  /// Whether the foreground IoT fallback is allowed to send a make-up ping to
  /// atlas-iot when the bg service is dead. Default OFF — flip via RC after
  /// the Shorebird patch lands.
  bool get fgFallbackEnabled =>
      _cache['fgFallbackEnabled'] ?? ConfigDefaults.fgFallbackEnabled;

  /// Minimum staleness of the last successful IoT send (seconds) before the
  /// foreground fallback is allowed to fire. Below this, we trust the bg
  /// service to keep up.
  int get fgFallbackStalenessThresholdSeconds =>
      _cache['fgFallbackStalenessThresholdSeconds'] ??
      ConfigDefaults.fgFallbackStalenessThresholdSeconds;

  /// Check if intervals have changed (for job re-registration)
  bool hasIntervalsChanged(Map<String, int> oldIntervals) {
    return oldIntervals['battery'] != batteryCollectionInterval ||
        oldIntervals['send'] != sendInterval ||
        oldIntervals['cleanup'] != cleanupInterval;
  }

  /// Reset instance (useful for testing)
  static void resetInstance() {
    _instance = null;
  }
}
