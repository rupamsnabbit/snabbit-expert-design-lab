import 'dart:async';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_service.dart';
import 'config_defaults.dart';

/// Syncs IoT configuration from Firebase Remote Config to SharedPreferences
/// Runs on foreground thread and notifies background thread of updates
class ConfigSync {
  static final ConfigSync _instance = ConfigSync._internal();
  static ConfigSync get instance => _instance;
  factory ConfigSync() => _instance;
  ConfigSync._internal();

  static final Logger _logger = Logger();

  final RemoteConfigService _remoteConfig = RemoteConfigService.instance;
  StreamSubscription<Set<String>>? _updateSubscription;
  bool _isListening = false;

  /// Callback when config is updated (to notify background thread)
  Function()? onConfigUpdated;

  /// Start listening to Remote Config updates and sync to SharedPreferences
  Future<void> startListening() async {
    if (_isListening) return;

    // Fetch latest config from Firebase before initial sync
    try {
      _logger.d('[IoT Config] Fetching from Firebase...');
      final activated = await _remoteConfig.fetchAndActivate();
      _logger.d('[IoT Config] fetchAndActivate: $activated');
    } catch (e) {
      _logger.w('[IoT Config] Fetch failed, using cached values', error: e);
    }

    // Initial sync (will use freshly fetched values or cached values if fetch failed)
    await syncConfigToPreferences();

    // Notify background thread of initial config (so IoT manager initializes on first app launch)
    onConfigUpdated?.call();

    // Listen for updates
    _updateSubscription = _remoteConfig.onUpdatedKeys.listen((updatedKeys) async {
      // Check if any IoT keys were updated
      final iotKeysUpdated = updatedKeys.any((key) => key.startsWith('iot_'));

      if (iotKeysUpdated) {
        _logger.i('[IoT Config] Remote Config updated, syncing...');
        try {
          // Sync updated config to SharedPreferences
          await syncConfigToPreferences();

          // Notify background thread
          onConfigUpdated?.call();
        } catch (e) {
          _logger.e('[IoT Config] Failed to sync after real-time update', error: e);
          // Don't rethrow - allow listener to continue receiving future updates
        }
      }
    });

    _isListening = true;
  }

  /// Stop listening to Remote Config updates
  Future<void> stopListening() async {
    await _updateSubscription?.cancel();
    _updateSubscription = null;
    _isListening = false;
  }

  /// Sync all IoT config keys from Remote Config to SharedPreferences
  /// Uses prefix 'iot_config_' to avoid conflicts
  Future<void> syncConfigToPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // API enabled flag from Remote Config
      final apiEnabled = _remoteConfig.getBool('iot_api_enabled',
          defaultValue: ConfigDefaults.apiEnabled);
      await prefs.setBool('iot_config_api_enabled', apiEnabled);

      // Skip location/battery in runnerAppCurrentState when IoT handles it
      final skipIotWithRunnerState = _remoteConfig.getBool(
          'iot_skip_location_battery_in_runner_state',
          defaultValue: ConfigDefaults.skipIotWithRunnerState);
      await prefs.setBool('iot_config_skip_location_battery_in_runner_state', skipIotWithRunnerState);

      _logger.d('[IoT Config] Synced: api_enabled=$apiEnabled, skip_location_in_runner_state=$skipIotWithRunnerState');

      await prefs.setInt(
        'iot_config_battery_collection_interval_seconds',
        _remoteConfig.getInt('iot_battery_collection_interval_seconds',
          defaultValue: ConfigDefaults.batteryCollectionInterval),
      );

      await prefs.setInt(
        'iot_config_location_interval_idle',
        _remoteConfig.getInt('iot_location_interval_idle',
          defaultValue: ConfigDefaults.locationIntervalIdle),
      );

      await prefs.setInt(
        'iot_config_location_interval_assigned',
        _remoteConfig.getInt('iot_location_interval_assigned',
          defaultValue: ConfigDefaults.locationIntervalAssigned),
      );

      await prefs.setInt(
        'iot_config_location_interval_in_transit',
        _remoteConfig.getInt('iot_location_interval_in_transit',
          defaultValue: ConfigDefaults.locationIntervalInTransit),
      );

      await prefs.setInt(
        'iot_config_location_interval_on_job',
        _remoteConfig.getInt('iot_location_interval_on_job',
          defaultValue: ConfigDefaults.locationIntervalOnJob),
      );

      await prefs.setInt(
        'iot_config_location_interval_offline',
        _remoteConfig.getInt('iot_location_interval_offline',
          defaultValue: ConfigDefaults.locationIntervalOffline),
      );

      await prefs.setInt(
        'iot_config_location_interval_default',
        _remoteConfig.getInt('iot_location_interval_default',
          defaultValue: ConfigDefaults.locationIntervalDefault),
      );

      await prefs.setInt(
        'iot_config_send_interval_seconds',
        _remoteConfig.getInt('iot_send_interval_seconds',
          defaultValue: ConfigDefaults.sendInterval),
      );

      await prefs.setInt(
        'iot_config_max_battery_records',
        _remoteConfig.getInt('iot_max_battery_records',
          defaultValue: ConfigDefaults.maxBatteryRecords),
      );

      await prefs.setInt(
        'iot_config_max_location_records',
        _remoteConfig.getInt('iot_max_location_records',
          defaultValue: ConfigDefaults.maxLocationRecords),
      );

      await prefs.setInt(
        'iot_config_api_timeout_seconds',
        _remoteConfig.getInt('iot_api_timeout_seconds',
          defaultValue: ConfigDefaults.apiTimeout),
      );

      await prefs.setInt(
        'iot_config_cleanup_interval_seconds',
        _remoteConfig.getInt('iot_cleanup_interval_seconds',
          defaultValue: ConfigDefaults.cleanupInterval),
      );

      await prefs.setInt(
        'iot_config_kill_switch_max_wait_seconds',
        _remoteConfig.getInt('iot_kill_switch_max_wait_seconds',
          defaultValue: ConfigDefaults.killSwitchMaxWait),
      );

      await prefs.setInt(
        'iot_config_device_state_collection_interval_seconds',
        _remoteConfig.getInt('iot_device_state_collection_interval_seconds',
          defaultValue: ConfigDefaults.deviceStateCollectionInterval),
      );

      await prefs.setInt(
        'iot_config_max_device_state_records',
        _remoteConfig.getInt('iot_max_device_state_records',
          defaultValue: ConfigDefaults.maxDeviceStateRecords),
      );

      // Foreground IoT fallback gates
      await prefs.setBool(
        'iot_config_fg_fallback_enabled',
        _remoteConfig.getBool('iot_fg_fallback_enabled',
            defaultValue: ConfigDefaults.fgFallbackEnabled),
      );

      await prefs.setInt(
        'iot_config_fg_fallback_staleness_threshold_seconds',
        _remoteConfig.getInt(
            'iot_fg_fallback_staleness_threshold_seconds',
            defaultValue:
                ConfigDefaults.fgFallbackStalenessThresholdSeconds),
      );
    } catch (e) {
      _logger.e('[IoT Config] Sync failed', error: e);
      rethrow;
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    await stopListening();
  }
}
