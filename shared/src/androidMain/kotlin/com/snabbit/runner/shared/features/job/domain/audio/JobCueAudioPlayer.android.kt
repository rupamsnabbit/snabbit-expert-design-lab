package com.snabbit.runner.shared.features.job.domain.audio

import android.app.Application
import android.media.AudioAttributes
import android.media.MediaPlayer
import com.snabbit.runner.shared.core.AppDispatchers
import com.snabbit.runner.shared.core.CrashReporter
import java.io.File
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.withContext

/**
 * Plays a localized job-cue clip via [MediaPlayer] under `USAGE_MEDIA` / `CONTENT_TYPE_SPEECH` — a
 * routine voice prompt, so (unlike the SOS siren's
 * [com.snabbit.runner.shared.features.kavach.sos.domain.deterrence.AndroidDeterrenceAudioPlayer]) it does
 * NOT hijack/max the alarm stream. `USAGE_MEDIA` routes to `STREAM_MUSIC`, so the media-volume slider
 * governs it and it plays even in ringer silent/vibrate mode — the state runners are usually in. (An
 * `ASSISTANCE_SONIFICATION` usage routes to `STREAM_SYSTEM`, which is silenced outright in silent mode.)
 * Clip bytes are cached to a per-clip cacheDir file once ([MediaPlayer] needs a file path, not bytes).
 *
 * All disk + [MediaPlayer] setup runs on [AppDispatchers.io]: the scheduler arms this on
 * `viewModelScope` (`Dispatchers.Main.immediate`), so without the hop the ~70 KB cache write plus the
 * blocking `prepare()` would run on the UI thread. (`DeterrenceCoordinator` avoids this by construction —
 * it is built with `defaultAppDispatchers()` — so this is not inherited from the SOS player.)
 */
internal class AndroidJobCueAudioPlayer(
    private val app: Application,
    private val crashReporter: CrashReporter,
    private val dispatchers: AppDispatchers,
    private val readBytes: suspend (String) -> ByteArray,
) : JobCueAudioPlayer {

    private var player: MediaPlayer? = null
    // Serialize play-setup vs stop(): a fresh cue firing while a prior one is torn down could release a
    // half-prepared player. Mirrors AndroidDeterrenceAudioPlayer.
    private val lock = Any()

    override suspend fun play(assetPath: String): Boolean = withContext(dispatchers.io) {
        // Best-effort — a cue must NEVER crash the job flow. Guard every throw site (asset read, cache
        // write, MediaPlayer prepare IOException / start IllegalStateException). Off-main via
        // dispatchers.io; only the brief MediaPlayer setup is additionally synchronized. Returns false
        // when the clip is missing or playback fails, so the caller doesn't record a silent "play".
        var created: MediaPlayer? = null
        try {
            val file = cacheFileFor(assetPath) ?: return@withContext false
            synchronized(lock) {
                runCatching { player?.release() }
                val mp = MediaPlayer()
                created = mp
                player = mp
                mp.setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .build(),
                )
                mp.setDataSource(file.absolutePath)
                // Release the SPECIFIC clip that finished, not the `player` field — a back-to-back cue
                // may already own the field, and a completion callback queued on the looper must not
                // release the newer clip.
                mp.setOnCompletionListener { releaseIfCurrent(mp) }
                mp.prepare()
                mp.start()
            }
            true
        } catch (e: CancellationException) {
            throw e
        } catch (t: Throwable) {
            crashReporter.report(t, mapOf("op" to "job_cue_play", "asset" to assetPath))
            created?.let { releaseIfCurrent(it) }
            false
        }
    }

    override fun stop() = releaseCurrent()

    /**
     * Materialize the clip to a stable per-clip cacheDir file (atomic temp-then-rename, length-checked so
     * a truncated write can't be served forever). Returns null on empty bytes (missing asset) so [play]
     * no-ops instead of `prepare()`-failing on a 0-byte file. The cache name is derived from the asset's
     * filename, which is unique per (language, cue) in our set.
     */
    private suspend fun cacheFileFor(assetPath: String): File? {
        val name = "job_cue_${assetPath.substringAfterLast('/')}"
        val f = File(app.cacheDir, name)
        if (!f.exists() || f.length() == 0L) {
            val bytes = readBytes(assetPath)
            if (bytes.isEmpty()) return null
            val tmp = File(app.cacheDir, "$name.${System.nanoTime()}.tmp")
            tmp.writeBytes(bytes)
            if (!tmp.renameTo(f)) tmp.delete()
        }
        return f.takeIf { it.length() > 0L }
    }

    /** Release [mp] and clear [player] only if it's still the current clip (don't clobber a newer cue). */
    private fun releaseIfCurrent(mp: MediaPlayer) = synchronized(lock) {
        runCatching { mp.release() }
        if (player === mp) player = null
    }

    private fun releaseCurrent() = synchronized(lock) {
        runCatching { player?.release() }
        player = null
    }
}
