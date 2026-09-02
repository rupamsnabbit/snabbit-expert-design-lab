package com.snabbit.runner.shared.features.kavach.sos.domain.deterrence

import kotlinx.cinterop.ExperimentalForeignApi
import kotlinx.cinterop.addressOf
import kotlinx.cinterop.convert
import kotlinx.cinterop.usePinned
import platform.AVFAudio.AVAudioPlayer
import platform.AVFAudio.AVAudioSession
import platform.AVFAudio.AVAudioSessionCategoryOptionDuckOthers
import platform.AVFAudio.AVAudioSessionCategoryPlayback
import platform.AVFAudio.AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation
import platform.AVFAudio.setActive
import platform.Foundation.NSData
import platform.Foundation.create

/**
 * AVAudioPlayer under an `AVAudioSession` `.playback` + `.duckOthers`, per-player volume at max.
 * Modern iOS exposes NO public API to set the device system volume (verified), so — unlike
 * Flutter's unofficial MPVolumeSlider hack — system volume is NOT forced here; ducking + max
 * per-player gain is the sanctioned equivalent. Plays the in-memory clip bytes directly (no file).
 */
@OptIn(ExperimentalForeignApi::class)
internal class IosDeterrenceAudioPlayer(
    private val bytesProvider: suspend () -> ByteArray,
) : DeterrenceAudioPlayer {

    private var player: AVAudioPlayer? = null

    override suspend fun playDeterrence() {
        val bytes = bytesProvider()
        if (bytes.isEmpty()) return
        val data = bytes.usePinned { pinned ->
            NSData.create(bytes = pinned.addressOf(0), length = bytes.size.convert())
        }
        AVAudioSession.sharedInstance().apply {
            setCategory(AVAudioSessionCategoryPlayback, AVAudioSessionCategoryOptionDuckOthers, null)
            setActive(true, null)
        }
        player = AVAudioPlayer(data = data, error = null).apply {
            volume = 1.0f
            numberOfLoops = 0
            prepareToPlay()
            play()
        }
    }

    override fun stop() {
        player?.stop()
        player = null
        // We activated the session with .duckOthers; deactivate on stop and notify others so their
        // audio un-ducks/resumes — otherwise everything stays ducked for the process lifetime (#4).
        AVAudioSession.sharedInstance().setActive(false, AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation, null)
    }
}
