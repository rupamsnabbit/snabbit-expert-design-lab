import 'package:snabbit_runner/services/mixpanel_setup.dart';

/// Job-lifecycle analytics helper.
///
/// Holds the currently-active `job_id`/`customer_id` and merges them into
/// every event fired through [logEvent], so call sites only pass the
/// event-specific properties.
///
/// Lifecycle: [setActiveJob] is called when a job is assigned to the
/// runner; the IDs are overwritten on the next [setActiveJob] call when
/// a new job arrives. There is no explicit clear — between jobs the
/// runner is on non-job screens which do not fire lifecycle events, so
/// stale IDs cannot leak.
class JobLifecycleAnalytics {
  JobLifecycleAnalytics._();

  static dynamic _jobId;
  static dynamic _customerId;

  static void setActiveJob({dynamic jobId, dynamic customerId}) {
    _jobId = jobId;
    _customerId = customerId;
  }

  /// Fires the event on Mixpanel + CleverTap fire-and-forget. The active
  /// `job_id` and `customer_id` are merged in; call-site props win on
  /// conflict.
  static void logEvent(String name, Map<String, dynamic> props) {
    final merged = <String, dynamic>{
      if (_jobId != null) 'job_id': _jobId,
      if (_customerId != null) 'customer_id': _customerId,
      ...props,
    };
    // Single forward — the central catalog fans this to Mixpanel + CleverTap.
    MixpanelSetup.logEvent(name, merged);
  }
}
