package com.snabbit.runner.shared.features.kavach.sos.domain.deterrence

/**
 * Plays the bundled SOS deterrence clip once. Loudness intent is platform-specific:
 * Android raises the alarm stream to max for the clip then RESTORES the prior level (Flutter gap
 * C13 — it left the volume at max); iOS ducks other audio (`.playback` + `.duckOthers`) at
 * per-player max. Modern iOS has NO public API to set the device system volume (verified: only the
 * user-driven MPVolumeView slider), so Flutter's `setVolume(1.0)` system-volume force is not replicated.
 */
interface DeterrenceAudioPlayer {
    /** Play the clip once. */
    suspend fun playDeterrence()

    /** Stop + release if mid-playback (cancel path). */
    fun stop()
}
