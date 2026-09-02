import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/alarm_silencer.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/utils/common_methods.dart';

/// Dart handler for KMP → Flutter Profile actions
/// (`com.snabbit.runner/profile_actions`; mirrors `ProfileActionsPlugin`).
///
/// These are one-shot actions the native/Compose side can't run itself because
/// they touch Flutter-only services:
///  - **silentNotifications** — stop notifications + audio and persist the
///    `'stopped'` state, matching the Flutter drawer's Silent-notifications tile
///    (the CleverTap event is fired KMP-side).
///  - **silenceAlarm** — the Dart end of the KMP `AlarmController` seam: a
///    Compose CTA acknowledged an alerting event (AWOL "I understand", delayed
///    check-in "Check In"), so the alert sound must stop. Narrower than
///    `silentNotifications` on purpose — it silences the alarm only, leaving
///    posted notifications and the `'stopped'` marker alone.
///
/// The new-job alert START/STOP edges are NOT here — `JobScreenLauncherPlugin`'s
/// store observer drives those over its own `job_overlay` channel (`JobOverlayChannel`)
/// so the handler is guaranteed attached when an edge fires.
///
/// Call [init] once at app startup so the handler is ready before the Profile
/// tab can invoke it.
class ProfileActionsChannel {
  ProfileActionsChannel._();

  static const MethodChannel _channel =
      MethodChannel('com.snabbit.runner/profile_actions');

  static void init() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'silentNotifications':
          await _silentNotifications();
          return null;
        case 'panCardUnavailable':
          _setPanCardUnavailable();
          return null;
        case 'silenceAlarm':
          await AlarmSilencer.silence();
          return null;
        default:
          throw MissingPluginException(
            'ProfileActionsChannel: unknown method ${call.method}',
          );
      }
    });
  }

  /// Set the profile provider's transient `panCardUnavailable` flag (runner tapped
  /// Create-ePAN in the native PAN sheet). Mirrors the drawer sheet, which sets it
  /// before opening the ePAN portal so PAN/TDS nags are suppressed until the next
  /// `runnersMeSetup`. Best-effort — a missing context/provider just no-ops.
  static void _setPanCardUnavailable() {
    try {
      final context = GlobalState().navigatorKey.currentContext;
      if (context == null) return;
      Provider.of<UserProfileProvider>(context, listen: false)
          .panCardUnavailable = true;
    } catch (e) {
      MonitoringServiceHelper.logError(
        'profile_pan_unavailable_failed',
        {'error': e.toString()},
      );
    }
  }

  static Future<void> _silentNotifications() async {
    try {
      await silenceNewJobAlert();
    } catch (e) {
      MonitoringServiceHelper.logError(
        'profile_silent_notifications_failed',
        {'error': e.toString()},
      );
    }
  }
}
