import 'package:vibration/vibration.dart';

import 'package:snabbit_runner/services/awol_alarm_service.dart';
import 'package:snabbit_runner/services/localized_audio_service.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';

/// Silences the alert alarm when the runner **acknowledges** the event that
/// raised it — "I understand" on an AWOL breach, "Check In" on a delayed
/// check-in. Before this existed the alarm's lifetime was bound only to server
/// state (`RunnerRtDataProvider._evaluateAwolAlarm`), so an acknowledged alert
/// kept sounding for the rest of its repeat count.
///
/// Deliberately **not** scoped per alert type. Every alert sound in the app
/// shares one player (`GlobalState().audioPlayer`), so "stop the noise" is
/// inherently a global action — a per-feature silencer would leave a
/// concurrently-playing alarm running and give each caller a different thing to
/// remember. Each underlying service still applies its own semantics (notably
/// [AwolAlarmService.silence], which preserves the breach de-dupe episode so an
/// acknowledged breach can't re-alarm while a genuinely new one still can).
///
/// This is also the Dart end of the KMP `AlarmController` seam — the Compose
/// AWOL / check-in CTAs reach it via `ProfileActionsChannel.silenceAlarm`.
///
/// Best-effort by contract: every step swallows and logs its own failure, and
/// [silence] never throws, because it is called from CTA handlers whose real
/// job (dismissing a dialog, opening the OTP sheet) must not be blocked by an
/// audio-plugin error.
class AlarmSilencer {
  AlarmSilencer._();

  /// Stops any alert sound and vibration currently playing.
  ///
  /// Safe to call when nothing is playing — each step is a no-op then.
  static Future<void> silence() async {
    // AWOL first: it also halts its repeat loop, which a bare player stop
    // cannot do.
    await AwolAlarmService.silence();
    await LocalizedAudioService.stopExpertNotMoving();
    try {
      await Vibration.cancel();
    } catch (e) {
      await MonitoringServiceHelper.logError(
        'alarm_silencer_vibration_cancel_failed',
        {'error': e.toString()},
      ).catchError((_) {});
    }
  }
}
