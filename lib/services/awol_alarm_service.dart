import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';

import 'package:snabbit_runner/models/awol/awol_models.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/utils/common_methods.dart';

/// Plays (and stops) the AWOL breach alarm, extracted from `main.dart`'s
/// `loopSound` switch so the same playback can be driven from **two** places:
///
///  1. A genuine named FCM push (`AWOL_BREACH`) routed through `loopSound`.
///  2. A NONE→breach transition detected off the polled / MQTT-stored
///     `current_state` in [RunnerRtDataProvider] — the v2 AWOL path is
///     store/poll-driven, and the backend's state-refresh nudge is a nameless
///     data-only wake push, so `loopSound` never reaches its AWOL branch for
///     that path. Tying the alarm to AWOL-state detection (not the push name)
///     makes it fire regardless of how the breach is discovered.
///
/// Both paths funnel through [playAlarm], which de-dupes so the same breach
/// never alarms twice (see the de-dupe note on [playAlarm]).
class AwolAlarmService {
  AwolAlarmService._();

  static const String _hotspotBreachAsset =
      'notification_sounds/awol_alarm.wav';
  static const String _jobBreachAsset =
      'notification_sounds/awol_job_alarm.mp3';

  // Match `main.dart`'s existing AWOL branches: the hotspot breach loops 6×,
  // the movement/JOB breach 3×, both with a 1s gap between plays.
  static const int _hotspotBreachRepeats = 6;
  static const int _jobBreachRepeats = 3;

  /// De-dupe state for the current active-breach episode.
  ///  - [_episodeActive]: an AWOL breach is currently active and has been
  ///    alarmed. Cleared by [stop] when the breach resolves (RE_ENTERED) or is
  ///    dismissed, so a genuinely new breach later can alarm again.
  ///  - [_episodeEventId]: the breach `event_id` we alarmed for (may be null
  ///    when the source carried no id — an id-less episode adopts the first
  ///    non-null id it later sees for the same breach).
  ///  - [_episodeState]: the [AwolState] the episode alarmed for. A call with
  ///    a different state (breach→job escalation, even with the same
  ///    `event_id`) is a new alarmable moment, not a duplicate.
  ///  - [_lastPlayedAt]: backstop cooldown for near-simultaneous re-triggers
  ///    from the two paths above when no `event_id` is available to match on.
  static bool _episodeActive = false;
  static String? _episodeEventId;
  static AwolState? _episodeState;
  static DateTime? _lastPlayedAt;

  /// SharedPreferences keys for the cross-isolate episode marker (see the
  /// cross-isolate note on [playAlarm]). Written when an alarm actually
  /// plays, cleared by [stop].
  static const String _episodeIdPrefsKey = 'awol_alarm_episode_id';
  static const String _episodeStatePrefsKey = 'awol_alarm_episode_state';
  static const String _playedAtPrefsKey = 'awol_alarm_played_at_ms';

  /// Skip window for an **id-less** cross-isolate marker match. An anonymous
  /// episode can't be matched by `event_id`, so a marker match where either
  /// side lacks an id is indistinguishable from a later genuine breach. A
  /// breach episode lasts tens of minutes, so 10 minutes bounds the
  /// cross-isolate double-alarm (background push → app opened moments later)
  /// without permanently silencing a later real breach.
  static const Duration _idlessMarkerTtl = Duration(minutes: 10);

  /// Monotonic token bumped by [stop] and by each new [playAlarm] dispatch.
  /// [_defaultPlayback]'s repeat loop re-checks it before every play, so a
  /// stop (breach resolved) or a superseding alarm actually halts the loop —
  /// `audioPlayer.stop()` alone only cuts the clip currently playing; without
  /// this the next iteration would restart the alarm after it was stopped.
  static int _playbackGeneration = 0;

  /// Genuine AWOL breaches are geofence-driven and minutes apart, so a short
  /// cooldown never suppresses a real new breach — it only collapses a
  /// push + state-transition double-fire for the same breach.
  static const Duration _cooldown = Duration(seconds: 15);

  /// Plays the AWOL alarm for [state] (only [AwolState.breach] and
  /// [AwolState.job] play — anything else is a no-op).
  ///
  /// De-dupe: the alarm can be triggered for the same breach from both a named
  /// FCM push and a state transition. We skip when we're already in the same
  /// breach episode — matched by [eventId] when both sides carry one; an
  /// id-less episode ADOPTS the first non-null [eventId] it sees, keeping the
  /// whole continuous episode as one (a named push may carry no id while the
  /// later poll for the same breach does) — or when a re-trigger landed inside
  /// [_cooldown] (backstop for sources that carry no `event_id`).
  ///
  /// Escalation: a call whose [state] differs from the active episode's
  /// (breach→job re-using the same `event_id`) is a NEW alarmable moment — it
  /// plays, beats the cooldown, and becomes the episode's state.
  ///
  /// Cross-isolate: the named-push path runs in the FCM background isolate
  /// (`firebaseMessagingBackgroundHandler`), whose copy of the statics above
  /// is separate from the main isolate's — fresh statics on app open would
  /// re-alarm the same breach off the cached state. The last-alarmed episode
  /// is therefore also persisted to SharedPreferences and checked after the
  /// in-memory gates — see [_adoptPersistedEpisodeIfSame].
  static Future<void> playAlarm(AwolState state, {String? eventId}) async {
    if (state != AwolState.breach && state != AwolState.job) return;

    final now = DateTime.now();
    final sameEpisode = _episodeActive &&
        state == _episodeState &&
        (eventId == null ||
            _episodeEventId == null ||
            eventId == _episodeEventId);
    if (sameEpisode) {
      // An id-less episode adopts the first non-null id observed for it, so
      // later same-id observations keep matching (and stop() clears it all).
      _episodeEventId ??= eventId;
      return;
    }

    final withinCooldown =
        _lastPlayedAt != null && now.difference(_lastPlayedAt!) < _cooldown;
    // The cooldown only collapses re-triggers of the SAME breach (either side
    // missing an id, or ids matching — and the same state kind: a breach→job
    // escalation must alarm even seconds after the breach alarm). Two distinct
    // non-null ids are two distinct breach events — a genuinely new breach
    // must alarm even inside the cooldown, otherwise it is silenced forever
    // (the provider records it as alarmed and never retries).
    final sameBreachInCooldown = withinCooldown &&
        state == _episodeState &&
        (eventId == null ||
            _episodeEventId == null ||
            eventId == _episodeEventId);
    if (sameBreachInCooldown) {
      _episodeEventId ??= eventId;
      return;
    }

    // Claim the episode in-memory BEFORE the async persisted-marker check so
    // a near-simultaneous second trigger in THIS isolate still lands on the
    // synchronous gates above (no await sits between the gates and this
    // claim). If the marker then shows another isolate already alarmed this
    // breach, the claim simply becomes the adopted episode.
    _episodeActive = true;
    _episodeEventId = eventId;
    _episodeState = state;
    _lastPlayedAt = now;

    final alreadyAlarmedInOtherIsolate =
        await _adoptPersistedEpisodeIfSame(state, eventId);
    if (alreadyAlarmedInOtherIsolate) return;

    // Capture the generation AT the bump (mirrors LocalizedAudioService's
    // `++_expertNotMovingGeneration`), then thread it into playback. Re-reading
    // `_playbackGeneration` inside [_defaultPlayback] instead would swallow a
    // silence()/stop() that lands during the [_persistEpisodeMarker] await
    // below: that acknowledgement's bump would already be folded into
    // `_playbackGeneration` by the time the loop guard read it, so the loop's
    // captured == current check would pass and an acknowledged alarm would play
    // out its full 6/3-repeat run regardless.
    final generation = ++_playbackGeneration;
    await _persistEpisodeMarker(state, eventId, now);
    await playback(state, eventId, generation);
  }

  /// Cross-isolate de-dupe check (see the note on [playAlarm]): reads the
  /// episode marker persisted by whichever isolate last alarmed and reports
  /// whether this call is for that same already-alarmed breach.
  ///
  /// Same non-null `event_id` AND same state kind → skip regardless of age.
  /// Either side id-less (same state kind) → skip only within
  /// [_idlessMarkerTtl], adopting the marker's id when we have none. A
  /// different non-null id, or a different state kind (escalation), plays.
  ///
  /// Fails OPEN (returns false → plays): the alarm is safety-critical, so a
  /// prefs failure must not silence a genuine breach.
  static Future<bool> _adoptPersistedEpisodeIfSame(
      AwolState state, String? eventId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // SharedPreferences caches per isolate at first load; reload() so this
      // isolate sees a marker the other isolate wrote after that load.
      await prefs.reload();
      final markerState = prefs.getString(_episodeStatePrefsKey);
      final markerPlayedAtMs = prefs.getInt(_playedAtPrefsKey);
      if (markerState == null || markerPlayedAtMs == null) return false;
      // A different state kind is a breach→job escalation — always alarms.
      if (markerState != state.name) return false;
      final markerId = prefs.getString(_episodeIdPrefsKey);
      if (eventId != null && markerId != null) {
        // Ids on both sides: an exact match is the same breach no matter how
        // old the marker is; a mismatch is a genuinely new breach.
        return eventId == markerId;
      }
      // Either side is id-less — can't match by id, so bound the skip by the
      // TTL (see [_idlessMarkerTtl]).
      final playedAt = DateTime.fromMillisecondsSinceEpoch(markerPlayedAtMs);
      if (DateTime.now().difference(playedAt) >= _idlessMarkerTtl) {
        return false;
      }
      _episodeEventId ??= markerId;
      return true;
    } catch (e) {
      await MonitoringServiceHelper.logError('awol_alarm_marker_read_failed', {
        'error': e.toString(),
        'state': state.name,
        'event_id': eventId,
      }).catchError((_) {});
      return false;
    }
  }

  /// Persists the episode marker after an alarm actually plays, so the other
  /// isolate's [playAlarm] recognises the breach as already alarmed. Failures
  /// are logged and swallowed — the alarm itself must still play.
  static Future<void> _persistEpisodeMarker(
      AwolState state, String? eventId, DateTime playedAt) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (eventId == null) {
        await prefs.remove(_episodeIdPrefsKey);
      } else {
        await prefs.setString(_episodeIdPrefsKey, eventId);
      }
      await prefs.setString(_episodeStatePrefsKey, state.name);
      await prefs.setInt(_playedAtPrefsKey, playedAt.millisecondsSinceEpoch);
    } catch (e) {
      await MonitoringServiceHelper.logError('awol_alarm_marker_write_failed', {
        'error': e.toString(),
        'state': state.name,
        'event_id': eventId,
      }).catchError((_) {});
    }
  }

  /// The actual audio + vibration playback, split from the de-dupe gate in
  /// [playAlarm] so the gate can be unit-tested without the audio/vibration
  /// platform plugins. Production code must NEVER reassign this — it exists
  /// solely as a test seam; tests swap it via [debugSetPlayback].
  @visibleForTesting
  static Future<void> Function(AwolState state, String? eventId, int generation)
      playback = _defaultPlayback;

  static Future<void> _defaultPlayback(
      AwolState state, String? eventId, int generation) async {
    final asset =
        state == AwolState.job ? _jobBreachAsset : _hotspotBreachAsset;
    final repeats =
        state == AwolState.job ? _jobBreachRepeats : _hotspotBreachRepeats;
    // [generation] is captured at the dispatch bump in [playAlarm] and passed
    // in — deliberately NOT re-read from `_playbackGeneration` here, so a
    // silence()/stop() during playAlarm's persist await still supersedes us.
    try {
      // Cut any sound already playing so the alarm isn't layered under it
      // (loopSound does this at its top; the state-transition path does not).
      await GlobalState().audioPlayer.stop();
      setMaxVolume();
      await Vibration.vibrate(duration: 2000);
      var timesPlayed = 0;
      while (timesPlayed < repeats) {
        // Superseded by stop() (breach resolved) or a newer alarm — halt
        // instead of restarting the clip.
        if (generation != _playbackGeneration) return;
        await GlobalState()
            .audioPlayer
            .play(AssetSource(asset), volume: desiredVolume);
        // Let the clip finish before the next loop iteration.
        await Future.delayed(const Duration(milliseconds: 1000));
        timesPlayed++;
      }
    } catch (e) {
      await MonitoringServiceHelper.logError('awol_alarm_playback_failed', {
        'error': e.toString(),
        'state': state.name,
        'event_id': eventId,
      }).catchError((_) {});
    }
  }

  /// Test-only: override the playback impl and reset the in-memory de-dupe
  /// state (the persisted marker is controlled by the test's
  /// `SharedPreferences.setMockInitialValues`).
  @visibleForTesting
  static void debugSetPlayback(
      Future<void> Function(AwolState state, String? eventId, int generation)?
          impl) {
    playback = impl ?? _defaultPlayback;
    _episodeActive = false;
    _episodeEventId = null;
    _episodeState = null;
    _lastPlayedAt = null;
  }

  /// Halts an in-flight alarm **without** clearing the de-dupe episode.
  ///
  /// This is the *acknowledgement* stop — the runner tapped "I understand" (or
  /// checked in) while still outside the hotspot. The breach is unresolved, so
  /// the episode must survive: keeping [_episodeActive] (and the persisted
  /// marker) means the same breach can't re-alarm off the next poll / MQTT
  /// snapshot / background push, while a genuinely new breach — different
  /// `event_id`, or a breach→job escalation — still alarms normally.
  ///
  /// Contrast [stop], which also clears the episode because the breach itself
  /// resolved and a later one *should* alarm fresh. Never throws: silencing is
  /// best-effort and must not break the CTA that triggered it.
  static Future<void> silence() async {
    // Halt the repeat loop (see [_playbackGeneration]) — stopping the player
    // only cuts the clip currently playing.
    _playbackGeneration++;
    try {
      await GlobalState().audioPlayer.stop();
    } catch (e) {
      await MonitoringServiceHelper.logError(
              'awol_alarm_silence_failed', {'error': e.toString()})
          .catchError((_) {});
    }
  }

  /// Stops any looping AWOL alarm and clears the de-dupe episode — in-memory
  /// AND the persisted cross-isolate marker — so the next breach alarms fresh
  /// in every isolate. Called when the breach resolves (RE_ENTERED). For an
  /// acknowledgement while the breach is still active, use [silence] instead.
  /// Never throws.
  static Future<void> stop() async {
    _episodeActive = false;
    _episodeEventId = null;
    _episodeState = null;
    _lastPlayedAt = null;
    // Halt an in-flight playback repeat loop (see [_playbackGeneration]) —
    // stopping the player only cuts the clip currently playing.
    _playbackGeneration++;
    try {
      await GlobalState().audioPlayer.stop();
    } catch (e) {
      await MonitoringServiceHelper.logError(
          'awol_alarm_stop_failed', {'error': e.toString()}).catchError((_) {});
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_episodeIdPrefsKey);
      await prefs.remove(_episodeStatePrefsKey);
      await prefs.remove(_playedAtPrefsKey);
    } catch (e) {
      await MonitoringServiceHelper.logError(
              'awol_alarm_marker_clear_failed', {'error': e.toString()})
          .catchError((_) {});
    }
  }
}
