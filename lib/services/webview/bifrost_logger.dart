import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';

/// Narrow logging seam used by bifrost code. Lets tests inject a silent or
/// recording logger without pulling in `MonitoringServiceHelper`, whose
/// singletons touch platform channels (audio player, http client, etc.).
abstract class BifrostLogger {
  Future<void> logInfo(String event, Map<String, dynamic> data);
  Future<void> logError(String event, Map<String, dynamic> data);
}

/// Production default: forwards to the app's monitoring stack.
///
/// `logError` fans out to **both** Coralogix (via `MonitoringServiceHelper`)
/// **and** Firebase Crashlytics. Coralogix has volume / consumption limits
/// that bifrost error spikes could blow past; Crashlytics is the always-on
/// safety net so we never lose error signal even if Coralogix is throttled.
class MonitoringBifrostLogger implements BifrostLogger {
  const MonitoringBifrostLogger();

  @override
  Future<void> logInfo(String event, Map<String, dynamic> data) =>
      MonitoringServiceHelper.logInfo(event, data);

  @override
  Future<void> logError(String event, Map<String, dynamic> data) async {
    await MonitoringServiceHelper.logError(event, data);
    // Non-fatal Crashlytics record so the error shows up in the dashboard
    // without crashing the app. `reason` is the bifrost event name; the
    // payload goes into `information` for filterability.
    await FirebaseCrashlytics.instance.recordError(
      event,
      StackTrace.current,
      reason: event,
      information: [for (final e in data.entries) '${e.key}=${e.value}'],
      fatal: false,
    );
  }
}

/// Silent logger used in tests that don't care about log output.
class NullBifrostLogger implements BifrostLogger {
  const NullBifrostLogger();

  @override
  Future<void> logInfo(String event, Map<String, dynamic> data) async {}

  @override
  Future<void> logError(String event, Map<String, dynamic> data) async {}
}
