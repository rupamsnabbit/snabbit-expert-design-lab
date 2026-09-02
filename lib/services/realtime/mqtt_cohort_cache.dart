import 'package:shared_preferences/shared_preferences.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';

/// Persists whether the runner is in the `mqtt_config` (KMP realtime) cohort, so
/// an **offline cold-start** can still route to the KMP stack — which renders the
/// last-known state from the on-device DB — instead of the "no internet" screen.
///
/// `mqtt_config` only arrives inside `GET /runners/me`, and [UserProfile.toMap]
/// does not serialise it, so there is no Dart-readable copy on an offline boot.
/// This flag is the durable signal: written on every online `runners/me`
/// (true when `mqtt_config` is present, false otherwise, so leaving the cohort is
/// respected), read when that call fails offline.
class MqttCohortCache {
  const MqttCohortCache._();

  static const String _key = 'is_mqtt_cohort';

  /// Remember the current cohort membership from a fresh online `runners/me`.
  static Future<void> setCohort(bool isCohort) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, isCohort);
    } catch (e) {
      MonitoringServiceHelper.logError(
        'mqtt_cohort_cache_write_failed',
        {'error': e.toString()},
      );
    }
  }

  /// Whether the last online `runners/me` put this runner in the cohort. Fails
  /// SAFE (false) so a read error just shows the standard offline screen, never
  /// a wrong KMP route.
  static Future<bool> isCohort() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_key) ?? false;
    } catch (e) {
      MonitoringServiceHelper.logError(
        'mqtt_cohort_cache_read_failed',
        {'error': e.toString()},
      );
      return false;
    }
  }

  /// Same as [isCohort] but re-reads from disk first. `SharedPreferences` caches
  /// its values per isolate at first load, so the background location isolate's
  /// snapshot never reflects a main-isolate [setCohort] write made after that
  /// isolate started. A `reload()` picks it up — needed when this flag is read
  /// cross-isolate (e.g. the background `current_state` cohort gate). Fails SAFE
  /// (false) so a read error just leaves the legacy polling path intact.
  static Future<bool> isCohortFresh() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      return prefs.getBool(_key) ?? false;
    } catch (e) {
      MonitoringServiceHelper.logError(
        'mqtt_cohort_cache_read_failed',
        {'error': e.toString()},
      );
      return false;
    }
  }
}
