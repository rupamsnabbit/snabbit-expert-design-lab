package com.snabbit.runner.shared.features.kavach.sos.domain.deterrence

import android.app.Application
import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import com.snabbit.runner.shared.core.CrashReporter
import java.io.File
import kotlinx.coroutines.CancellationException

/**
 * MediaPlayer under `USAGE_ALARM`. Raises `STREAM_ALARM` to max (capturing the prior level) and
 * RESTORES it on completion or [stop] — the C13 fix (Flutter left the volume at max). The clip
 * bytes are cached to a cacheDir file once (MediaPlayer needs a path, not a byte array).
 */
internal class AndroidDeterrenceAudioPlayer(
    private val app: Application,
    private val crashReporter: CrashReporter,
    private val bytesProvider: suspend () -> ByteArray,
) : DeterrenceAudioPlayer {

    private val audioManager: AudioManager
        get() = app.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    private var player: MediaPlayer? = null
    private var priorVolume: Int? = null
    private var cachedFile: File? = null
    // Serialize play-setup vs stop/restore: schedule() runs playDeterrence while cancel() runs
    // stop()→restoreAndRelease() on the same pool; overlap could restore a not-yet-captured
    // priorVolume (or restore before the max is set) → STREAM_ALARM stuck at max.
    private val lock = Any()

    override suspend fun playDeterrence() {
        // Deterrence is best-effort — it must NEVER crash an active SOS. Guard every throw site (cache
        // writeBytes IOException, setStreamVolume SecurityException under DND, MediaPlayer prepare
        // IOException / start IllegalStateException). On any failure restore the volume + release so
        // STREAM_ALARM is never left stuck at max (the C13 concern). Mirrors restoreAndRelease's runCatching.
        try {
            val file = cachedFile ?: File(app.cacheDir, CACHE_NAME).also { f ->
                // Atomic materialize (temp-then-rename): a crash/kill mid-write can't leave a truncated
                // final file that prepare() would silently fail on forever. Length check mirrors
                // ModelAssetResolver — existence alone would serve a 0-byte file forever.
                if (!f.exists() || f.length() == 0L) {
                    // Unique temp name so the write is self-contained — a fixed "$CACHE_NAME.tmp" would let
                    // two concurrent materializations interleave the same temp + race the rename.
                    val tmp = File(app.cacheDir, "$CACHE_NAME.${System.nanoTime()}.tmp")
                    tmp.writeBytes(bytesProvider())
                    if (!tmp.renameTo(f)) tmp.delete()
                }
                if (f.length() > 0L) cachedFile = f
            }
            synchronized(lock) {
                val am = audioManager
                priorVolume = am.getStreamVolume(STREAM)
                am.setStreamVolume(STREAM, am.getStreamMaxVolume(STREAM), 0)
                // Publish BEFORE prepare()/start(): `apply` assigns only after the whole block returns,
                // so a throw there would leave the MediaPlayer unreachable and the catch would release
                // the previous (null) reference instead. We hold `lock`, and restoreAndRelease() takes
                // the same lock, so stop() can't see a half-prepared player.
                val mp = MediaPlayer()
                player = mp
                mp.setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build(),
                )
                mp.setDataSource(file.absolutePath)
                mp.setOnCompletionListener { restoreAndRelease() }
                mp.prepare()
                mp.start()
            }
        } catch (e: CancellationException) {
            throw e
        } catch (t: Throwable) {
            // The siren is safety-critical and best-effort — report, else it fails silently during a
            // real SOS. Every sibling in this feature reports; this catch was the only one that didn't.
            crashReporter.report(t, mapOf("op" to "deterrence_play"))
            restoreAndRelease()
        }
    }

    override fun stop() = restoreAndRelease()

    private fun restoreAndRelease() = synchronized(lock) {
        priorVolume?.let { prior -> runCatching { audioManager.setStreamVolume(STREAM, prior, 0) } }
        priorVolume = null
        runCatching { player?.release() }
        player = null
    }

    private companion object {
        const val STREAM = AudioManager.STREAM_ALARM
        const val CACHE_NAME = "shield_deterrence.mp3"
    }
}
