import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/runner_rt_data.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/mixpanel_setup.dart';

class TrackingCommon {
  TrackingCommon._();

  /// Returns `{expert_name, expert_id, job_id}` from the current navigator
  /// context. Returns an empty map if the context is unavailable.
  static Map<String, dynamic> getExpertAttributes() {
    try {
      final context = GlobalState().navigatorKey.currentContext;
      if (context != null) {
        final userProfile = Provider.of<UserProfileProvider>(
          context,
          listen: false,
        );
        final user = userProfile.user;
        final runnerRtData = Provider.of<RunnerRtDataProvider>(
          context,
          listen: false,
        );
        return {
          'expert_name': user?.name,
          'expert_id': user?.id,
          'job_id': runnerRtData.jobId,
        };
      }
    } catch (e, stackTrace) {
      FirebaseCrashlytics.instance.recordError(
        e, stackTrace,
        reason: 'TRACKING_GET_EXPERT_ATTRIBUTES',
        fatal: false,
      );
    }
    return {};
  }

  /// Logs [event] + [props] to Mixpanel, recording any error to Crashlytics
  /// under the given [crashlyticsContext] prefix.
  static Future<void> logMixpanelEvent(
    String event,
    Map<String, dynamic> props, {
    required String crashlyticsContext,
  }) async {
    try {
      await MixpanelSetup.logEvent(event, props);
    } catch (e, stackTrace) {
      FirebaseCrashlytics.instance.recordError(
        e, stackTrace,
        reason: '${crashlyticsContext}_LOG_EVENT: $event',
        fatal: false,
      );
    }
  }
}
