import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snabbit_runner/models/awol/awol_models.dart';
import 'package:snabbit_runner/services/awol_alarm_service.dart';

/// De-dupe / transition-gate tests for [AwolAlarmService]. The real audio +
/// vibration playback is swapped for a counting stub via [debugSetPlayback],
/// so these exercise the gate logic without the platform plugins.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  // stop() touches GlobalState().audioPlayer; stub the audioplayers channels
  // so their MissingPluginExceptions can't escape as uncaught zone errors.
  setUpAll(() {
    for (final channel in const [
      MethodChannel('xyz.luan/audioplayers'),
      MethodChannel('xyz.luan/audioplayers.global'),
    ]) {
      messenger.setMockMethodCallHandler(channel, (call) async => null);
    }
  });

  late List<AwolState> played;

  setUp(() {
    // Fresh (empty) persisted cross-isolate marker unless a test seeds one.
    SharedPreferences.setMockInitialValues({});
    played = <AwolState>[];
    AwolAlarmService.debugSetPlayback((state, eventId, generation) async {
      played.add(state);
    });
  });

  tearDown(() {
    // Restore the real playback impl and clear de-dupe state between tests.
    AwolAlarmService.debugSetPlayback(null);
  });

  test('plays the hotspot alarm on the first breach', () async {
    await AwolAlarmService.playAlarm(AwolState.breach, eventId: 'e1');
    expect(played, [AwolState.breach]);
  });

  test('does not re-play for the same breach event_id', () async {
    await AwolAlarmService.playAlarm(AwolState.breach, eventId: 'e1');
    await AwolAlarmService.playAlarm(AwolState.breach, eventId: 'e1');
    expect(played, [AwolState.breach]);
  });

  test('de-dupes a nameless re-trigger for the same active episode', () async {
    // A named push (no event_id) then the poll transition (no event_id) for
    // the same breach must alarm only once.
    await AwolAlarmService.playAlarm(AwolState.breach);
    await AwolAlarmService.playAlarm(AwolState.breach);
    expect(played, [AwolState.breach]);
  });

  test('silence() still lets a genuinely new breach alarm', () async {
    await AwolAlarmService.playAlarm(AwolState.breach, eventId: 'e1');
    await AwolAlarmService.silence(); // acknowledged
    // A different event_id is a different breach — acknowledging the first one
    // must not silence the next.
    await AwolAlarmService.playAlarm(AwolState.breach, eventId: 'e2');
    expect(played, [AwolState.breach, AwolState.breach]);
  });

  test('silence() still lets a breach→job escalation alarm', () async {
    await AwolAlarmService.playAlarm(AwolState.breach, eventId: 'e1');
    await AwolAlarmService.silence(); // acknowledged
    // Same episode, escalated state kind — a new alarmable moment.
    await AwolAlarmService.playAlarm(AwolState.job, eventId: 'e1');
    expect(played, [AwolState.breach, AwolState.job]);
  });

  test('re-plays after the breach resolves via stop()', () async {
    await AwolAlarmService.playAlarm(AwolState.breach, eventId: 'e1');
    await AwolAlarmService.stop(); // RE_ENTERED / dismissed
    await AwolAlarmService.playAlarm(AwolState.job, eventId: 'e2');
    expect(played, [AwolState.breach, AwolState.job]);
  });

  test('a distinct new breach event alarms even inside the cooldown', () async {
    // Two different non-null event_ids are two different breaches — the 15s
    // cooldown must not silence the second one (the provider records it as
    // alarmed and would never retry).
    await AwolAlarmService.playAlarm(AwolState.breach, eventId: 'e1');
    await AwolAlarmService.playAlarm(AwolState.breach, eventId: 'e2');
    expect(played, [AwolState.breach, AwolState.breach]);
  });

  test('ignores a non-breach state', () async {
    await AwolAlarmService.playAlarm(AwolState.reEntered, eventId: 'e1');
    expect(played, isEmpty);
  });

  test('an id-less episode adopts the first non-null event_id it sees',
      () async {
    // A named push with no event_id starts the episode; the poll then
    // delivers the SAME breach with an id — that must be adopted, not
    // re-alarmed, and later same-id observations must keep matching.
    await AwolAlarmService.playAlarm(AwolState.breach);
    await AwolAlarmService.playAlarm(AwolState.breach, eventId: 'e1');
    await AwolAlarmService.playAlarm(AwolState.breach, eventId: 'e1');
    expect(played, [AwolState.breach]);
  });

  test('a breach→job escalation with the same event_id alarms again', () async {
    // The backend re-uses the breach event_id when escalating to JOB — a
    // different state kind is a new alarmable moment, and (both calls land
    // well inside the 15s cooldown here) it must beat the cooldown too.
    await AwolAlarmService.playAlarm(AwolState.breach, eventId: 'e1');
    await AwolAlarmService.playAlarm(AwolState.job, eventId: 'e1');
    expect(played, [AwolState.breach, AwolState.job]);
  });

  group('cross-isolate persisted marker', () {
    test('skips when the same id + state already alarmed in another isolate',
        () async {
      // Simulates the FCM background isolate having alarmed and written the
      // marker; this (fresh-statics) isolate must not re-alarm — id + state
      // match skips regardless of the marker's age.
      SharedPreferences.setMockInitialValues({
        'awol_alarm_episode_id': 'e1',
        'awol_alarm_episode_state': 'breach',
        'awol_alarm_played_at_ms': DateTime.now()
            .subtract(const Duration(hours: 2))
            .millisecondsSinceEpoch,
      });
      await AwolAlarmService.playAlarm(AwolState.breach, eventId: 'e1');
      expect(played, isEmpty);
    });

    test('a different event_id plays despite the persisted marker', () async {
      SharedPreferences.setMockInitialValues({
        'awol_alarm_episode_id': 'e1',
        'awol_alarm_episode_state': 'breach',
        'awol_alarm_played_at_ms': DateTime.now().millisecondsSinceEpoch,
      });
      await AwolAlarmService.playAlarm(AwolState.breach, eventId: 'e2');
      expect(played, [AwolState.breach]);
    });

    test('a breach→job escalation plays despite a same-id persisted marker',
        () async {
      SharedPreferences.setMockInitialValues({
        'awol_alarm_episode_id': 'e1',
        'awol_alarm_episode_state': 'breach',
        'awol_alarm_played_at_ms': DateTime.now().millisecondsSinceEpoch,
      });
      await AwolAlarmService.playAlarm(AwolState.job, eventId: 'e1');
      expect(played, [AwolState.job]);
    });

    test('an id-less marker skips within the TTL', () async {
      // No id on the marker (named push carried none) — same state kind
      // within the 10-minute TTL is treated as the same episode.
      SharedPreferences.setMockInitialValues({
        'awol_alarm_episode_state': 'breach',
        'awol_alarm_played_at_ms': DateTime.now()
            .subtract(const Duration(minutes: 5))
            .millisecondsSinceEpoch,
      });
      await AwolAlarmService.playAlarm(AwolState.breach, eventId: 'e1');
      expect(played, isEmpty);
    });

    test('an id-less marker older than the TTL plays', () async {
      SharedPreferences.setMockInitialValues({
        'awol_alarm_episode_state': 'breach',
        'awol_alarm_played_at_ms': DateTime.now()
            .subtract(const Duration(minutes: 11))
            .millisecondsSinceEpoch,
      });
      await AwolAlarmService.playAlarm(AwolState.breach, eventId: 'e1');
      expect(played, [AwolState.breach]);
    });

    test('silence() keeps the marker so the same breach stays de-duped',
        () async {
      SharedPreferences.setMockInitialValues({});
      await AwolAlarmService.playAlarm(AwolState.breach, eventId: 'e1');
      expect(played, [AwolState.breach]);
      // Runner tapped "I understand" while STILL outside the hotspot. Unlike
      // stop() (breach resolved), the episode must survive — otherwise the very
      // next poll / MQTT snapshot re-alarms the breach they just acknowledged.
      await AwolAlarmService.silence();
      await AwolAlarmService.playAlarm(AwolState.breach, eventId: 'e1');
      expect(played, [AwolState.breach]);
    });

    test('stop() clears the marker so the next breach alarms fresh', () async {
      SharedPreferences.setMockInitialValues({
        'awol_alarm_episode_id': 'e1',
        'awol_alarm_episode_state': 'breach',
        'awol_alarm_played_at_ms': DateTime.now().millisecondsSinceEpoch,
      });
      // Skipped-and-adopted from the marker...
      await AwolAlarmService.playAlarm(AwolState.breach, eventId: 'e1');
      expect(played, isEmpty);
      // ...so stop() must clear BOTH the in-memory episode and the marker,
      // letting a later breach with the same id alarm again.
      await AwolAlarmService.stop();
      await AwolAlarmService.playAlarm(AwolState.breach, eventId: 'e1');
      expect(played, [AwolState.breach]);
    });
  });
}
