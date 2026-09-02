package com.snabbit.runner.shared.features.job.domain.audio

/**
 * Plays a bundled localized job-cue voice clip (half-time / T-minus-10) once, **natively** per platform
 * (Android `MediaPlayer`, iOS `AVAudioPlayer`) — NOT via the Flutter host. Deliberately native so the
 * two in-progress cues survive the eventual Flutter removal; they only fire while the KMP job screen is
 * alive, so there is no background/isolate concern (auto-checkout, which must fire in the killed FCM
 * isolate, stays host-owned in Dart `loopSound`).
 *
 * [assetPath] is the full Flutter asset path, e.g. `assets/notification_sounds/hi/half_time_hindi.mp3`
 * (built by [JobCueAssetResolver]); the platform actual reads the clip bytes through a `readBytes`
 * lambda wired in `platformModule` to the shared general-asset reader — so this feature never imports
 * the kavach reader type. Best-effort: a missing clip / decode failure is reported and swallowed, never
 * crashing the job flow. Modelled on the SOS
 * [com.snabbit.runner.shared.features.kavach.sos.domain.deterrence.DeterrenceAudioPlayer].
 */
interface JobCueAudioPlayer {
    /**
     * Play the clip at [assetPath] once; replaces any clip still playing.
     * @return true if playback actually started; false if the clip was missing/empty or playback
     *   failed — so the caller can avoid reporting a "played" that produced no sound.
     */
    suspend fun play(assetPath: String): Boolean

    /** Stop + release if mid-playback (job change / cancel path). */
    fun stop()
}
