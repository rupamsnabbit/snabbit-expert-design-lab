package com.snabbit.runner.shared.features.job.domain.audio

import com.snabbit.runner.shared.core.CrashReporter
import kotlinx.cinterop.ExperimentalForeignApi
import kotlinx.cinterop.addressOf
import kotlinx.cinterop.convert
import kotlinx.cinterop.usePinned
import kotlinx.coroutines.CancellationException
import platform.AVFAudio.AVAudioPlayer
import platform.AVFAudio.AVAudioSession
import platform.AVFAudio.AVAudioSessionCategoryOptionDuckOthers
import platform.AVFAudio.AVAudioSessionCategoryPlayback
import platform.AVFAudio.AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation
import platform.AVFAudio.setActive
import platform.Foundation.NSData
import platform.Foundation.create

/**
 * Plays a localized job-cue clip via `AVAudioPlayer` under an `AVAudioSession` `.playback` +
 * `.duckOthers`, from in-memory bytes (no file). Mirrors
 * [com.snabbit.runner.shared.features.kavach.sos.domain.deterrence.IosDeterrenceAudioPlayer].
 */
@OptIn(ExperimentalForeignApi::class)
internal class IosJobCueAudioPlayer(
    private val crashReporter: CrashReporter,
    private val readBytes: suspend (String) -> ByteArray,
) : JobCueAudioPlayer {

    private var player: AVAudioPlayer? = null

    override suspend fun play(assetPath: String): Boolean {
        // Best-effort — a cue must never crash the job flow (parity with AndroidJobCueAudioPlayer).
        // Returns false when the clip is missing/empty or playback fails.
        try {
            val bytes = readBytes(assetPath)
            if (bytes.isEmpty()) return false
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
            return true
        } catch (e: CancellationException) {
            throw e
        } catch (t: Throwable) {
            crashReporter.report(t, mapOf("op" to "job_cue_play", "asset" to assetPath))
            return false
        }
    }

    override fun stop() {
        // Only deactivate the SHARED session if this player actually activated it — a stop() on a player
        // that never played (e.g. the scheduler's new-job reset) must not tear down another component's
        // active AVAudioSession.
        val active = player ?: return
        active.stop()
        player = null
        // We activated the session with .duckOthers; deactivate on stop and notify others so their
        // audio un-ducks/resumes — otherwise everything stays ducked for the process lifetime.
        AVAudioSession.sharedInstance().setActive(false, AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation, null)
    }
}
