/// Default values for IoT configuration
/// Used as fallback when Remote Config is unavailable
class ConfigDefaults {
  // Feature flags
  static const bool apiEnabled = false; // Default false, controlled by Remote Config
  static const bool skipIotWithRunnerState = false; // Default false for safety - only skip when IoT is explicitly enabled via Remote Config

  // Collection intervals (seconds)
  static const int batteryCollectionInterval = 60;
  static const int locationIntervalIdle = 60;
  static const int locationIntervalAssigned = 60;
  static const int locationIntervalInTransit = 60;
  static const int locationIntervalOnJob = 60;
  static const int locationIntervalOffline = 60;
  static const int locationIntervalDefault = 60;
  static const int sendInterval = 60;

  // Database limits
  static const int maxBatteryRecords = 60;
  static const int maxLocationRecords = 240;
  static const int maxDeviceStateRecords = 60;
  static const int deviceStateCollectionInterval = 60;

  // API and job intervals
  static const int apiTimeout = 10;
  static const int cleanupInterval = 3600; // 1 hour
  static const int killSwitchMaxWait = 15;

  // Foreground IoT fallback: when the bg service is dead and the app is
  // foregrounded, the main isolate piggybacks current_state's poll to send
  // a make-up ping to atlas-iot. Kill-switched OFF by default — flip via RC
  // once a Shorebird patch has rolled out.
  static const bool fgFallbackEnabled = false;
  static const int fgFallbackStalenessThresholdSeconds = 300; // 5 minutes

  /// Get all defaults as map for Remote Config
  static Map<String, dynamic> getAll() {
    return {
      'iot_api_enabled': apiEnabled,
      'iot_skip_location_battery_in_runner_state': skipIotWithRunnerState,
      'iot_battery_collection_interval_seconds': batteryCollectionInterval,
      'iot_location_interval_idle': locationIntervalIdle,
      'iot_location_interval_assigned': locationIntervalAssigned,
      'iot_location_interval_in_transit': locationIntervalInTransit,
      'iot_location_interval_on_job': locationIntervalOnJob,
      'iot_location_interval_offline': locationIntervalOffline,
      'iot_location_interval_default': locationIntervalDefault,
      'iot_send_interval_seconds': sendInterval,
      'iot_max_battery_records': maxBatteryRecords,
      'iot_max_location_records': maxLocationRecords,
      'iot_device_state_collection_interval_seconds': deviceStateCollectionInterval,
      'iot_max_device_state_records': maxDeviceStateRecords,
      'iot_api_timeout_seconds': apiTimeout,
      'iot_cleanup_interval_seconds': cleanupInterval,
      'iot_kill_switch_max_wait_seconds': killSwitchMaxWait,
      'iot_fg_fallback_enabled': fgFallbackEnabled,
      'iot_fg_fallback_staleness_threshold_seconds':
          fgFallbackStalenessThresholdSeconds,
    };
  }
}
