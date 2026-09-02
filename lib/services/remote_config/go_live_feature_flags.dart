import 'package:snabbit_runner/pages/go_live/go_live_v2/models/shift_time_bucket.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_keys.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_service.dart';

/// Shift hours bucket model for remote config
class ShiftHoursBucketConfig {
  final int startHours;
  final int endHours;
  final List<int> potentialEarnings; // [min, max]

  ShiftHoursBucketConfig({
    required this.startHours,
    required this.endHours,
    required this.potentialEarnings,
  });

  factory ShiftHoursBucketConfig.fromJson(Map<String, dynamic> json) {
    return ShiftHoursBucketConfig(
      startHours: json['start_hours'] as int? ?? 4,
      endHours: json['end_hours'] as int? ?? 8,
      potentialEarnings: (json['potential_earnings'] as List?)
              ?.map((e) => e as int)
              .toList() ??
          [15000, 24000],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'start_hours': startHours,
      'end_hours': endHours,
      'potential_earnings': potentialEarnings,
    };
  }
}

/// Feature flag configuration for Go Live V2 flow
///
/// Firebase Remote Config key: `enable_golive_v2`
/// JSON value format: `{"globallyEnabled": false, "tc_ids": [4, 6, 10, ...]}`
///
/// If `globallyEnabled` is true, all users see V2 flow.
/// Otherwise, only users whose TC ID is in `tc_ids` list will see V2 flow.
///
/// Shift Hours Remote Config key: `golive_v2_shift_hours`
/// JSON format:
/// ```json
/// {
///   "weekday": [
///     {"start_hours": 4, "end_hours": 8, "potential_earnings": [1200, 2000]},
///     {"start_hours": 8, "end_hours": 12, "potential_earnings": [2400, 4000]}
///   ],
///   "weekend": [
///     {"start_hours": 4, "end_hours": 8, "potential_earnings": [1500, 2500]},
///     {"start_hours": 8, "end_hours": 12, "potential_earnings": [3000, 5000]}
///   ]
/// }
/// ```
/// Note: potential_earnings is an array [minEarnings, maxEarnings]
class GoLiveFeatureFlags {
  GoLiveFeatureFlags._();

  /// Default config (V2 disabled by default)
  static const Map<String, dynamic> _defaultConfig = {
    'globallyEnabled': false,
    'tc_ids': <int>[],
  };

  /// Get the enable_golive_v2 config from Firebase Remote Config
  static Map<String, dynamic> _getConfig() {
    try {
      final remoteConfig = RemoteConfigService.instance;
      final json = remoteConfig.getJson(RemoteConfigKeys.enableGoLiveV2);
      // print("[GoLiveFeatureFlags] Remote Config JSON: $json");
      return json ?? _defaultConfig;
    } catch (_) {
      return _defaultConfig;
    }
  }

  /// Check if Go Live V2 is globally enabled for all users
  static bool get isGloballyEnabled {
    final config = _getConfig();
    return config['globallyEnabled'] == true;
  }

  /// Get the list of TC IDs that have V2 enabled
  static List<int> get enabledTcIds {
    final config = _getConfig();
    final tcIds = config['tc_ids'];
    if (tcIds is List) {
      return tcIds.whereType<int>().toList();
    }
    return [];
  }

  /// Check if Go Live V2 is enabled for a specific TC ID
  ///
  /// Returns true if:
  /// - `globallyEnabled` is true, OR
  /// - The given [tcId] is in the `tc_ids` list
  static bool isEnabledForTc(int? tcId) {
    if (isGloballyEnabled) {
      return true;
    }

    if (tcId == null) {
      return false;
    }

    return enabledTcIds.contains(tcId);
  }

  // ============ Shift Hours Configuration ============

  /// Default shift hours buckets (fallback if remote config fails)
  static final List<ShiftHoursBucketConfig> _defaultWeekdayBuckets = [
    ShiftHoursBucketConfig(
      startHours: 4,
      endHours: 8,
      potentialEarnings: [15000, 24000],
    ),
    ShiftHoursBucketConfig(
      startHours: 8,
      endHours: 12,
      potentialEarnings: [24000, 33000],
    ),
  ];

  static final List<ShiftHoursBucketConfig> _defaultWeekendBuckets = [
    ShiftHoursBucketConfig(
      startHours: 4,
      endHours: 8,
      potentialEarnings: [15000, 24000],
    ),
    ShiftHoursBucketConfig(
      startHours: 8,
      endHours: 12,
      potentialEarnings: [24000, 33000],
    ),
  ];

  /// Get shift hours config from remote config
  static Map<String, dynamic> _getShiftHoursConfig() {
    try {
      final remoteConfig = RemoteConfigService.instance;
      final json = remoteConfig.getJson(RemoteConfigKeys.goLiveV2ShiftHours);
      // print("[GoLiveFeatureFlags] Shift Hours Remote Config JSON: $json");
      return json ?? {};
    } catch (e) {
      // print("[GoLiveFeatureFlags] Error fetching shift hours config: $e");
      return {};
    }
  }

  /// Get weekday shift hours buckets from remote config
  ///
  /// Returns list of [ShiftHoursBucketConfig] for weekday shifts.
  /// Falls back to default if remote config is unavailable or invalid.
  static List<ShiftHoursBucketConfig> getWeekdayShiftHours() {
    try {
      final config = _getShiftHoursConfig();
      final weekdayList = config['weekday'] as List?;

      if (weekdayList == null || weekdayList.isEmpty) {
        // print(
        //     "[GoLiveFeatureFlags] No weekday shift hours in remote config, using defaults");
        return _defaultWeekdayBuckets;
      }

      final buckets = weekdayList
          .map((item) =>
              ShiftHoursBucketConfig.fromJson(item as Map<String, dynamic>))
          .toList();

      // print(
      //     "[GoLiveFeatureFlags] Loaded ${buckets.length} weekday shift hours from remote config");
      return buckets;
    } catch (e) {
      // print("[GoLiveFeatureFlags] Error parsing weekday shift hours: $e");
      return _defaultWeekdayBuckets;
    }
  }

  /// Get weekend shift hours buckets from remote config
  ///
  /// Returns list of [ShiftHoursBucketConfig] for weekend shifts.
  /// Falls back to default if remote config is unavailable or invalid.
  static List<ShiftHoursBucketConfig> getWeekendShiftHours() {
    try {
      final config = _getShiftHoursConfig();
      final weekendList = config['weekend'] as List?;

      if (weekendList == null || weekendList.isEmpty) {
        // print(
        //     "[GoLiveFeatureFlags] No weekend shift hours in remote config, using defaults");
        return _defaultWeekendBuckets;
      }

      final buckets = weekendList
          .map((item) =>
              ShiftHoursBucketConfig.fromJson(item as Map<String, dynamic>))
          .toList();

      // print(
      //     "[GoLiveFeatureFlags] Loaded ${buckets.length} weekend shift hours from remote config");
      return buckets;
    } catch (e) {
      // print("[GoLiveFeatureFlags] Error parsing weekend shift hours: $e");
      return _defaultWeekendBuckets;
    }
  }

  // ============ Recommended Shifts Limit ============

  /// Get recommended shifts limit from remote config
  ///
  /// This controls how many shift recommendations to fetch from the API.
  /// Default is 10 if remote config is unavailable.
  ///
  /// Remote Config key: `golive_v2_recommended_shifts_limit`
  /// Value type: Integer (e.g., 10, 15, 20)
  static int getRecommendedShiftsLimit() {
    try {
      final remoteConfig = RemoteConfigService.instance;
      final limit = remoteConfig.getInt(
        RemoteConfigKeys.goLiveV2RecommendedShiftsLimit,
      );

      if (limit > 0) {
        // print(
        //     "[GoLiveFeatureFlags] Recommended shifts limit from remote config: $limit");
        return limit;
      }

      // print("[GoLiveFeatureFlags] Invalid limit value, using default: 10");
      return 10;
    } catch (e) {
      // print(
      //     "[GoLiveFeatureFlags] Error fetching recommended shifts limit: $e, using default: 10");
      return 10;
    }
  }

  // ============ Shift Time Configuration ============

  /// Default shift time buckets (fallback if remote config fails)
  static final List<ShiftTimeBucket> _defaultWeekdayTimeBuckets = [
    ShiftTimeBucket(
      timeText: 'Morning',
      startHourRangeMin: 6,
      startHourRangeMax: 10,
    ),
    ShiftTimeBucket(
      timeText: 'Afternoon',
      startHourRangeMin: 11,
      startHourRangeMax: 17,
    ),
  ];

  static final List<ShiftTimeBucket> _defaultWeekendTimeBuckets = [
    ShiftTimeBucket(
      timeText: 'Morning',
      startHourRangeMin: 6,
      startHourRangeMax: 10,
    ),
    ShiftTimeBucket(
      timeText: 'Afternoon',
      startHourRangeMin: 11,
      startHourRangeMax: 17,
    ),
  ];

  /// Get shift time config from remote config
  static Map<String, dynamic> _getShiftTimeConfig() {
    try {
      final remoteConfig = RemoteConfigService.instance;
      final json = remoteConfig.getJson(RemoteConfigKeys.goLiveV2ShiftTime);
      // print("[GoLiveFeatureFlags] Shift Time Remote Config JSON: $json");
      return json ?? {};
    } catch (e) {
      // print("[GoLiveFeatureFlags] Error fetching shift time config: $e");
      return {};
    }
  }

  /// Get weekday shift time options from remote config
  ///
  /// Returns list of [ShiftTimeBucket] for weekday shift start times.
  /// Falls back to default if remote config is unavailable or invalid.
  ///
  /// Remote Config key: `golive_v2_shift_time`
  /// JSON format:
  /// ```json
  /// {
  ///   "weekday": [
  ///     {"time_text": "Morning", "start_hour_range": {"min": 6, "max": 10}},
  ///     {"time_text": "Afternoon", "start_hour_range": {"min": 11, "max": 15}}
  ///   ],
  ///   "weekend": [
  ///     {"time_text": "Morning", "start_hour_range": {"min": 8, "max": 12}},
  ///     {"time_text": "Afternoon", "start_hour_range": {"min": 13, "max": 17}}
  ///   ]
  /// }
  /// ```
  static List<ShiftTimeBucket> getWeekdayShiftTime() {
    try {
      final config = _getShiftTimeConfig();
      final weekdayList = config['weekday'] as List?;

      if (weekdayList == null || weekdayList.isEmpty) {
        // print(
        //     "[GoLiveFeatureFlags] No weekday shift time in remote config, using defaults");
        return _defaultWeekdayTimeBuckets;
      }

      final buckets = weekdayList
          .map((item) => ShiftTimeBucket.fromJson(item as Map<String, dynamic>))
          .toList();

      // print(
      //     "[GoLiveFeatureFlags] Loaded ${buckets.length} weekday shift time options from remote config");
      return buckets;
    } catch (e) {
      // print("[GoLiveFeatureFlags] Error parsing weekday shift time: $e");
      return _defaultWeekdayTimeBuckets;
    }
  }

  /// Get weekend shift time options from remote config
  ///
  /// Returns list of [ShiftTimeBucket] for weekend shift start times.
  /// Falls back to default if remote config is unavailable or invalid.
  static List<ShiftTimeBucket> getWeekendShiftTime() {
    try {
      final config = _getShiftTimeConfig();
      final weekendList = config['weekend'] as List?;

      if (weekendList == null || weekendList.isEmpty) {
        // print(
        //     "[GoLiveFeatureFlags] No weekend shift time in remote config, using defaults");
        return _defaultWeekendTimeBuckets;
      }

      final buckets = weekendList
          .map((item) => ShiftTimeBucket.fromJson(item as Map<String, dynamic>))
          .toList();

      // print(
      //     "[GoLiveFeatureFlags] Loaded ${buckets.length} weekend shift time options from remote config");
      return buckets;
    } catch (e) {
      // print("[GoLiveFeatureFlags] Error parsing weekend shift time: $e");
      return _defaultWeekendTimeBuckets;
    }
  }
}
