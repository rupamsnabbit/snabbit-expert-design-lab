import 'package:flutter/services.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/utils/common_methods.dart';

/// Dart side of the native `com.snabbit.runner/job_overlay` MethodChannel.
/// Mirrors
/// `android/app/src/main/kotlin/com/snabbit/runner/kmp_bridge/JobScreenLauncherPlugin.kt`.
///
/// Two directions on one channel:
///  - **Dart → KMP** (static writers): the logged-in runner's `service_id`, `runner_id`,
///    `expert_ameyo_support`, and localized job-surface labels, tagged onto the native
///    job-launch intents. Best-effort — any channel failure is swallowed + logged.
///  - **KMP → Dart** ([init]): `JobScreenLauncherPlugin`'s store observer fires the new-job
///    alert START/STOP edges here — over its OWN channel, so the handler is guaranteed
///    attached when an edge fires (`onAttachedToEngine` precedes `onAttachedToActivity`,
///    where the observer starts). This is the mqtt cohort's on-open alert trigger; the
///    Flutter/poll cohort still arms via `playSoundOnReceivingNewJob`.
class JobOverlayChannel {
  JobOverlayChannel._();

  static const MethodChannel _channel =
      MethodChannel('com.snabbit.runner/job_overlay');

  /// Registers the KMP → Dart handler for the new-job alert edges. Call once at
  /// startup (alongside the other channel handlers in `main()`). A native edge that
  /// arrives before this runs is held by Flutter's channel buffer and delivered on
  /// registration, so ordering against `main()` startup is not load-bearing.
  static void init() {
    _channel.setMethodCallHandler((call) async {
      try {
        switch (call.method) {
          // Rising edge: state ENTERED RUNNER_NEW_JOB → (re)arm the looping alert. Reuses the
          // same primitive the poll cohort uses, so playback matches across transports.
          case 'newJobAlertStart':
            await ensureNewJobLoopSound(isNewJob: true);
            return null;
          // Falling edge: the offer resolved (accepted / denied / expired) → hard-stop the loop.
          case 'newJobAlertStop':
            await silenceNewJobAlert();
            return null;
          default:
            throw MissingPluginException(
              'JobOverlayChannel: unknown method ${call.method}',
            );
        }
      } on MissingPluginException {
        rethrow;
      } catch (e) {
        // Best-effort: a failure here must never propagate back as an unhandled bridge
        // error. Log it (never swallow) so a broken alert edge is diagnosable.
        MonitoringServiceHelper.logError(
          'job_overlay_new_job_alert_failed',
          {'method': call.method, 'error': e.toString()},
        );
        return null;
      }
    });
  }

  /// Pushes the logged-in runner's `service_id` to the native launcher, which tags the New-Job
  /// launch intents so the KMP header shows the Cook vs Expert glyph. Best-effort; never throws.
  static Future<void> setServiceId(int? serviceId) {
    // Don't forward null — the native side would overwrite a previously-set id with null,
    // dropping the New-Job Cook/Expert glyph. Keep the last known-good id instead.
    if (serviceId == null) return Future<void>.value();
    return _channel.invokeMethod<void>('setServiceId', <String, Object?>{
      'service_id': serviceId,
    }).catchError((e) => _logFailure('setServiceId', e));
  }

  /// Pushes the logged-in runner's id to the native launcher — the delayed check-in
  /// disposition's `runner_id` on the KMP side. Best-effort; never throws.
  static Future<void> setRunnerId(int? runnerId) {
    return _channel.invokeMethod<void>('setRunnerId', <String, Object?>{
      'runner_id': runnerId,
    }).catchError((e) => _logFailure('setRunnerId', e));
  }

  /// Pushes the `expert_ameyo_support` Remote Config flag (delayed check-in FR-13
  /// callback mode) to the native launcher. Until pushed, the launcher defaults to
  /// dial mode (false) — the RC default. Best-effort; never throws.
  static Future<void> setAmeyoSupport(bool enabled) {
    return _channel.invokeMethod<void>('setAmeyoSupport', <String, Object?>{
      'enabled': enabled,
    }).catchError((e) => _logFailure('setAmeyoSupport', e));
  }

  /// Pushes the localized job-surface labels (keys = the native JobScreenExtras
  /// extra names) so JobActivity and the overlay render server-driven copy
  /// instead of English defaults. Re-pushed on every language settle
  /// (PartnerHome.didChangeDependencies). Best-effort; never throws.
  static Future<void> setJobStrings(Map<String, String> labels) {
    return _channel.invokeMethod<void>('setJobStrings', <String, Object?>{
      'labels': labels,
    }).catchError((e) => _logFailure('setJobStrings', e));
  }

  static void _logFailure(String op, Object e) {
    final tag = e is PlatformException
        ? 'PlatformException(${e.code})'
        : e.runtimeType.toString();
    MonitoringServiceHelper.logError('job_overlay_channel_error', {
      'op': op,
      'error': tag,
    }).catchError((_) {});
  }
}
