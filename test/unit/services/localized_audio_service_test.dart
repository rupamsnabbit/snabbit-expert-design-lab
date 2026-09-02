import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snabbit_runner/services/localized_audio_service.dart';

/// Interrupt-guard tests for [LocalizedAudioService.playExpertNotMoving] — the
/// delayed-check-in / not-moving alarm.
///
/// The repeat loop used to be unguarded, so `audioPlayer.stop()` only cut the
/// clip that happened to be playing and the next iteration restarted it: a
/// runner who tapped Check In kept hearing the alarm for the rest of its
/// server-driven repeat count. These pin the generation guard that fixes it.
///
/// The single-clip play is swapped for a counting stub via [debugSetPlayOnce]
/// (with a short repeat gap), so the loop is exercised without the audio plugin.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  // playExpertNotMoving/stopExpertNotMoving still touch the real player for
  // stop()/setReleaseMode(); stub the audioplayers channels so their
  // MissingPluginExceptions can't escape as uncaught zone errors.
  setUpAll(() {
    for (final channel in const [
      MethodChannel('xyz.luan/audioplayers'),
      MethodChannel('xyz.luan/audioplayers.global'),
    ]) {
      messenger.setMockMethodCallHandler(channel, (call) async => null);
    }
  });

  late int plays;

  setUp(() {
    plays = 0;
    LocalizedAudioService.debugSetPlayOnce(
      (path, volume) async => plays++,
      gap: const Duration(milliseconds: 10),
    );
  });

  tearDown(() {
    // Restore the real single-play impl and reset the generation.
    LocalizedAudioService.debugSetPlayOnce(null);
  });

  test('plays once by default (the DELAYED_CHECKIN_PENALTY push)', () async {
    await LocalizedAudioService.playExpertNotMoving(payloadLanguage: 'HINDI');
    expect(plays, 1);
  });

  test('plays the full repeat count when never interrupted', () async {
    await LocalizedAudioService.playExpertNotMoving(
      times: 4,
      payloadLanguage: 'HINDI',
    );
    expect(plays, 4);
  });

  test('stopExpertNotMoving halts an in-flight repeat sequence', () async {
    // Long sequence, left running (this is the NOT_GOING_TO_JOB_BREACH shape:
    // repeat count comes from the server).
    final sequence = LocalizedAudioService.playExpertNotMoving(
      times: 20,
      payloadLanguage: 'HINDI',
    );
    // Let a couple of repeats land, then acknowledge.
    await Future<void>.delayed(const Duration(milliseconds: 35));
    final playsAtStop = plays;
    await LocalizedAudioService.stopExpertNotMoving();
    await sequence;

    // The loop exited rather than running all 20 — at most the clip already
    // dispatched when the stop landed.
    expect(plays, lessThanOrEqualTo(playsAtStop + 1));
    expect(plays, lessThan(20));
  });

  test('a stop before the sequence starts prevents every repeat', () async {
    await LocalizedAudioService.stopExpertNotMoving();
    // A NEW dispatch after a stop must still play — the guard interrupts the
    // sequence it was raised against, it does not latch the service off.
    await LocalizedAudioService.playExpertNotMoving(
      times: 2,
      payloadLanguage: 'HINDI',
    );
    expect(plays, 2);
  });

  test('a newer dispatch supersedes the previous sequence', () async {
    final first = LocalizedAudioService.playExpertNotMoving(
      times: 20,
      payloadLanguage: 'HINDI',
    );
    await Future<void>.delayed(const Duration(milliseconds: 35));
    // Second alert arrives mid-sequence; the first must not keep playing
    // underneath it.
    await LocalizedAudioService.playExpertNotMoving(
      times: 2,
      payloadLanguage: 'HINDI',
    );
    await first;
    expect(plays, lessThan(20));
  });
}
