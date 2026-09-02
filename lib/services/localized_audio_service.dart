import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/globals.dart';

/// Sound keys for language-localized notification audio.
/// These map to filenames inside `assets/notification_sounds/<lang>/`.
class LocalizedSoundKeys {
  LocalizedSoundKeys._();
  static const String jobAcceptance = 'job_acceptance';
  static const String expertNotMoving = 'expert_not_moving';
  static const String autoOtRequest = 'auto_ot';
  static const String autoCheckout = 'auto_checkout';
}

/// Resolves and plays language-specific notification sounds.
///
/// In the foreground, reads [UserProfileProvider] via the navigator context.
/// In the killed state, reads [payloadLanguage] from the FCM data payload
/// (set by the backend on every relevant notification).
/// Falls back to Hindi when neither is available.
class LocalizedAudioService {
  LocalizedAudioService._();

  static const Map<String, _LangAsset> _langToAsset = {
    'ENGLISH': _LangAsset(folder: 'en', suffix: 'en'),
    'HINDI': _LangAsset(folder: 'hi', suffix: 'hindi'),
    'MARATHI': _LangAsset(folder: 'mr', suffix: 'marathi'),
    'KANNADA': _LangAsset(folder: 'ka', suffix: 'kannada'),
    'TELUGU': _LangAsset(folder: 'te', suffix: 'telugu'),
  };

  // Final fallback when no language can be resolved — Hindi.
  static const _LangAsset _fallback = _LangAsset(folder: 'hi', suffix: 'hindi');

  static const String _legacyAwolJobAsset =
      'notification_sounds/awol_job_alarm.mp3';
  static const String _legacyAutoOtAsset =
      'notification_sounds/auto_ot_request.mp3';
  // Non-localized fallback for the auto-checkout cue (the asset shipped before ECPO-982 localized it).
  static const String _legacyAutoCheckoutAsset =
      'notification_sounds/auto_checkout.mp3';
  static const String _legacyJobAllocYellow =
      'notification_sounds/yellow_sound.wav';
  static const String _legacyJobAllocRed = 'notification_sounds/red_sound.wav';
  static const String _legacyJobAllocDefault = 'custom_sound.wav';

  static const String _localizedAudioVersion = 'v2';

  /// Monotonic token bumped by [stopExpertNotMoving] and by each new
  /// [playExpertNotMoving] dispatch. The repeat loop re-checks it before every
  /// play, so a stop (the runner acknowledged the alert the sound belongs to)
  /// actually halts the sequence — `audioPlayer.stop()` alone only cuts the
  /// clip currently playing; without this the next iteration would restart the
  /// sound after it was stopped. Mirrors `AwolAlarmService._playbackGeneration`.
  static int _expertNotMovingGeneration = 0;

  static UserProfile? _currentUserProfile() {
    try {
      final ctx = GlobalState().navigatorKey.currentContext;
      if (ctx == null) return null;
      return Provider.of<UserProfileProvider>(ctx, listen: false).user;
    } catch (e, stackTrace) {
      FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'LocalizedAudioService: failed to resolve UserProfile',
        fatal: false,
      );
      return null;
    }
  }

  /// Resolves whether to use localized audio and which language to use.
  ///
  /// Single entry point for all payload/profile logic — [payloadLanguage]
  /// presence check and [_currentUserProfile] lookup happen exactly once.
  /// Adding a third sound type only requires calling this, not touching the guard.
  static ({bool useLocalized, String? language}) _resolveContext(
      String? payloadLanguage) {
    // All payloadLanguage guards consolidated here — one place to change.
    if (payloadLanguage?.isNotEmpty == true) {
      return (useLocalized: true, language: payloadLanguage);
    }
    final profile = _currentUserProfile();
    final v = profile?.audioVersion;
    return (
      useLocalized:
          v != null && v.trim().toLowerCase() == _localizedAudioVersion,
      language: profile?.languagePreference,
    );
  }

  static String _resolveAsset(String soundKey, String? languagePreference) {
    final key = languagePreference?.toUpperCase();
    final asset = (key == null ? null : _langToAsset[key]) ?? _fallback;
    return 'notification_sounds/${asset.folder}/${soundKey}_${asset.suffix}.mp3';
  }

  /// The language actually voiced for [languagePreference] — the language itself when its clip ships,
  /// else Hindi when it falls back to [_fallback]. Reported to analytics so `audio_language` matches
  /// what the runner heard, not an unmapped/blank preference. Mirrors KMP
  /// `JobCueAssetResolver.resolvedLanguage`.
  static String _resolvedLanguage(String? languagePreference) {
    final key = languagePreference?.toUpperCase();
    return (key != null && _langToAsset.containsKey(key)) ? key : 'HINDI';
  }

  static String _legacyJobAllocAsset(String? nudgeCount) {
    if (nudgeCount == '1') return _legacyJobAllocYellow;
    if (nudgeCount == '2') return _legacyJobAllocRed;
    return _legacyJobAllocDefault;
  }

  static String _jobAcceptanceAsset(
      {String? nudgeCount, String? payloadLanguage}) {
    final ctx = _resolveContext(payloadLanguage);
    if (ctx.useLocalized) {
      return _resolveAsset(LocalizedSoundKeys.jobAcceptance, ctx.language);
    }
    return _legacyJobAllocAsset(nudgeCount);
  }

  static String _expertNotMovingAsset({String? payloadLanguage}) {
    final ctx = _resolveContext(payloadLanguage);
    if (ctx.useLocalized) {
      return _resolveAsset(LocalizedSoundKeys.expertNotMoving, ctx.language);
    }
    return _legacyAwolJobAsset;
  }

  static String _autoOtRequestAsset({String? payloadLanguage}) {
    final ctx = _resolveContext(payloadLanguage);
    if (ctx.useLocalized) {
      return _resolveAsset(LocalizedSoundKeys.autoOtRequest, ctx.language);
    }
    return _legacyAutoOtAsset;
  }

  /// Plays the job-acceptance sound on a loop using the shared
  /// [GlobalState.audioPlayer]. Caller is responsible for stopping it
  /// (e.g. when the user acts on the offer).
  ///
  /// [nudgeCount] is the `nudge_count` value from the FCM data payload —
  /// only used in legacy mode to pick between yellow/red/default sounds.
  /// [payloadLanguage] is the language from the FCM data payload —
  /// used in killed/background state where Provider is unavailable.
  static Future<void> playJobAcceptance({
    double volume = 1.0,
    String? nudgeCount,
    AudioContext? ctx,
    String? payloadLanguage,
  }) async {
    final path = _jobAcceptanceAsset(
      nudgeCount: nudgeCount,
      payloadLanguage: payloadLanguage,
    );
    final player = GlobalState().audioPlayer;
    await player.stop();
    await player.setReleaseMode(ReleaseMode.loop);
    await player.play(AssetSource(path), volume: volume, ctx: ctx);
  }

  /// Plays the Auto-OT request sound once.
  ///
  /// [payloadLanguage] is the language from the FCM data payload —
  /// used in killed/background state where Provider is unavailable.
  static Future<void> playAutoOtRequest({
    double volume = 1.0,
    String? payloadLanguage,
  }) async {
    final path = _autoOtRequestAsset(payloadLanguage: payloadLanguage);
    final player = GlobalState().audioPlayer;
    await player.stop();
    await player.setReleaseMode(ReleaseMode.stop);
    await player.play(AssetSource(path), volume: volume);
  }

  /// Plays the auto-checkout sound once (ECPO-982) and returns the audio language actually voiced (for
  /// the `job_in_progress_audio_played` analytics event) — the resolved language, Hindi for an
  /// unmapped/blank preference — or null when it fell back to the non-localized legacy clip. Localized
  /// when the runner is on the localized-audio version; otherwise (or for English, whose
  /// `en/auto_checkout_en.mp3` isn't bundled yet) falls back to the legacy flat
  /// [_legacyAutoCheckoutAsset] (parity with the pre-localization behaviour — an English v2 runner keeps
  /// the clip they hear today instead of going silent).
  /// [payloadLanguage] is the FCM data-payload language for the killed/background path where the
  /// profile provider is unavailable.
  static Future<String?> playAutoCheckout({
    double volume = 1.0,
    String? payloadLanguage,
  }) async {
    final ctx = _resolveContext(payloadLanguage);
    // The English auto-checkout clip isn't shipped yet (ECPO-982 ships hi/mr/ka/te), so an English v2
    // runner would get silence — fall back to the legacy flat clip until en/auto_checkout_en.mp3 lands.
    // Every other language has its clip (unmapped/blank → Hindi via _resolveAsset).
    final useLocalized =
        ctx.useLocalized && ctx.language?.toUpperCase() != 'ENGLISH';
    final path = useLocalized
        ? _resolveAsset(LocalizedSoundKeys.autoCheckout, ctx.language)
        : _legacyAutoCheckoutAsset;
    final player = GlobalState().audioPlayer;
    await player.stop();
    await player.setReleaseMode(ReleaseMode.stop);
    await player.play(AssetSource(path), volume: volume);
    return useLocalized ? _resolvedLanguage(ctx.language) : null;
  }

  /// Plays the expert-not-moving sound [times] times sequentially.
  ///
  /// The sequence is interruptible — [stopExpertNotMoving] halts it mid-way
  /// (see [_expertNotMovingGeneration]), so the runner acknowledging the alert
  /// (tapping Check In) silences it instead of waiting it out.
  ///
  /// [payloadLanguage] is the language from the FCM data payload —
  /// used in killed/background state where Provider is unavailable.
  static Future<void> playExpertNotMoving({
    double volume = 1.0,
    int times = 1,
    String? payloadLanguage,
  }) async {
    final path = _expertNotMovingAsset(payloadLanguage: payloadLanguage);
    final player = GlobalState().audioPlayer;
    final generation = ++_expertNotMovingGeneration;
    await player.stop();
    await player.setReleaseMode(ReleaseMode.stop);
    for (var i = 0; i < times; i++) {
      // Superseded by stopExpertNotMoving() (runner acknowledged) or by a newer
      // dispatch — halt instead of restarting the clip.
      if (generation != _expertNotMovingGeneration) return;
      await playOnce(path, volume);
      await Future.delayed(_repeatGap);
    }
  }

  /// Gap between repeats. Also the granularity at which [stopExpertNotMoving]
  /// takes effect, so tests can shorten it via [debugSetPlayOnce].
  static Duration _repeatGap = const Duration(milliseconds: 1000);

  /// The single-clip play, split from the repeat loop in [playExpertNotMoving]
  /// so the loop's stop-guard can be unit-tested without the audio plugin.
  /// Production code must NEVER reassign this — it exists solely as a test
  /// seam; tests swap it via [debugSetPlayOnce]. Mirrors
  /// `AwolAlarmService.playback`.
  @visibleForTesting
  static Future<void> Function(String path, double volume) playOnce =
      _defaultPlayOnce;

  static Future<void> _defaultPlayOnce(String path, double volume) =>
      GlobalState().audioPlayer.play(AssetSource(path), volume: volume);

  /// Test-only: override the single-play impl (and optionally the repeat gap,
  /// to keep tests fast) and reset the interrupt generation.
  @visibleForTesting
  static void debugSetPlayOnce(
    Future<void> Function(String path, double volume)? impl, {
    Duration gap = const Duration(milliseconds: 1000),
  }) {
    playOnce = impl ?? _defaultPlayOnce;
    _repeatGap = gap;
    _expertNotMovingGeneration = 0;
  }

  /// Halts an in-flight [playExpertNotMoving] sequence and stops the player.
  ///
  /// Called when the runner acknowledges the alert the sound belongs to — the
  /// delayed-check-in / not-moving alarm must stop on the tap, not run to the
  /// end of its repeat count. Never throws: silencing is best-effort and must
  /// not break the CTA that triggered it.
  static Future<void> stopExpertNotMoving() async {
    _expertNotMovingGeneration++;
    try {
      await GlobalState().audioPlayer.stop();
    } catch (e, stackTrace) {
      FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        reason: 'LocalizedAudioService: failed to stop expert-not-moving',
        fatal: false,
      );
    }
  }
}

class _LangAsset {
  const _LangAsset({required this.folder, required this.suffix});
  final String folder;
  final String suffix;
}
