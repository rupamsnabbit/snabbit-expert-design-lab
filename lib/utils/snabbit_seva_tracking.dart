import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/clevertap.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';

class SnabbitSevaTracking {
  SnabbitSevaTracking._();

  static Map<String, dynamic>? _getCommonAttributes() {
    try {
      final context = GlobalState().navigatorKey.currentContext;
      if (context != null) {
        final userProfile = Provider.of<UserProfileProvider>(
          context,
          listen: false,
        );
        final user = userProfile.user;

        return {
          'runner_id': user?.id,
        };
      }
    } catch (e, st) {
      FirebaseCrashlytics.instance.recordError(e, st,
          reason: 'seva_tracking_common_attrs', fatal: false);
    }
    return null;
  }

  static Future<void> trackDrawerClick() async {
    final properties = {
      ...?_getCommonAttributes(),
    };
    await ClevertapSetup.logEvent(
        TrackingEvents.snabbitSevaDrawerClicked, properties);
  }

  static Future<void> trackWebPageLoaded() async {
    final properties = {
      ...?_getCommonAttributes(),
    };
    await ClevertapSetup.logEvent(
        TrackingEvents.snabbitSevaWebPageLoaded, properties);
  }

  static Future<void> trackWebPageLoadFailed({
    required String reason,
  }) async {
    final properties = {
      ...?_getCommonAttributes(),
      'reason': reason,
    };
    await ClevertapSetup.logEvent(
        TrackingEvents.snabbitSevaWebPageLoadFailed, properties);
  }

  static Future<void> trackExternalMapLinkClicked({
    required String url,
    required bool success,
  }) async {
    final properties = {
      ...?_getCommonAttributes(),
      'url': url,
      'success': success,
    };
    await ClevertapSetup.logEvent(
        TrackingEvents.snabbitSevaExternalMapLinkClicked, properties);
  }
}
