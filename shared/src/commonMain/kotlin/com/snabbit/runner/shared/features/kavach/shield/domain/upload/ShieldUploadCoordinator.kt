package com.snabbit.runner.shared.features.kavach.shield.domain.upload

import com.safetykavach.shield.core.ShieldController
import com.safetykavach.shield.core.event.ShieldEvent
import com.safetykavach.shield.recording.ClipStore
import com.snabbit.runner.shared.core.AppDispatchers
import com.snabbit.runner.shared.core.CrashReporter
import com.snabbit.runner.shared.core.analytics.AnalyticsTracker
import com.snabbit.runner.shared.core.config.RemoteConfigGateway
import com.snabbit.runner.shared.features.kavach.shield.data.upload.ShieldEncryptionMetadata
import com.snabbit.runner.shared.features.kavach.shield.data.store.ShieldFileReader
import com.snabbit.runner.shared.features.kavach.shield.data.upload.ShieldKeyWrapper
import com.snabbit.runner.shared.features.kavach.shield.data.upload.ShieldUploadQueue
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/**
 * Wires plugin `EncryptedAudio` clips into the upload outbox (Step 7.4) — 1:1 with the Flutter
 * `shield_event_handler`: read the `.enc` bytes → RSA-wrap the AES key → enqueue (with job/duration/
 * sos context) → `discardAESKey()` → delete the file. Collects on its own [scope].
 *
 * The clip context isn't on the event, so it's sourced via seams: [currentJobId] (drops the clip
 * when null, exactly like Flutter's job-null skip), [isSos], and RC-driven duration.
 *
 * Eager Koin single (`createdAtStart`): on construction it attaches the `EncryptedAudio` collector
 * AND flushes any rows persisted from a prior session ([ShieldUploadQueue.processQueue]) — so a
 * backlog survives a restart. Clips carry their own `jobId` (stamped by the plugin at recording
 * start); [currentJobId] is the fallback, latched by the arm sites — so a clip uploads whenever a job
 * owned it and is dropped only on a genuine job-null (Flutter's job-null
 * skip). The manual-vs-normal duration split is collapsed to sos-vs-normal here.
 */
class ShieldUploadCoordinator(
    private val shield: ShieldController,
    private val queue: ShieldUploadQueue,
    private val keyWrapper: ShieldKeyWrapper,
    private val fileReader: ShieldFileReader,
    private val remoteConfig: RemoteConfigGateway,
    private val currentJobId: () -> Int?,
    private val isSos: () -> Boolean,
    private val analytics: AnalyticsTracker,
    private val dispatchers: AppDispatchers,
    private val crashReporter: CrashReporter,
    /** Null on iOS / standalone: no sweep, so a clip left on disk stays there. */
    private val clipStore: ClipStore? = null,
) {
    private val scope = CoroutineScope(SupervisorJob() + dispatchers.default)

    init {
        // Sweep BEFORE the flush so clips stranded on disk join this pass rather than waiting a session.
        scope.launch {
            runCatching { sweepStrandedClips() }
                .onFailure { crashReporter.report(it, mapOf("op" to "shield_clip_sweep")) }
            runCatching { queue.processQueue() }
        }
        scope.launch {
            shield.events.collect { event ->
                if (event is ShieldEvent.EncryptedAudio) handleEncryptedAudio(event)
            }
        }
    }

    /**
     * A `.enc` still on disk means the host never finished enqueuing it — the app deletes the file only
     * after the row is committed. Re-enqueue from the sidecar; without one the AES key is gone and the
     * clip is unrecoverable, so drop it and count it rather than accumulating dead files.
     */
    private suspend fun sweepStrandedClips() {
        val store = clipStore ?: return
        // Newest first: each enqueue runs the MAX_PENDING cap, so a backlog larger than the cap evicts as
        // it sweeps. Ordering makes that deterministic — the newest clips survive instead of whichever the
        // filesystem happened to list last. SOS clips survive regardless (the cap orders is_sos first).
        val clips = store.listPendingClips().sortedByDescending { it.sidecar?.createdAt ?: 0L }
        for (clip in clips) {
            val sidecar = clip.sidecar
            if (sidecar == null) {
                analytics.track("expert_shield_upload_dropped", mapOf("reason" to "clip_sidecar_missing"))
                store.delete(clip.filePath)
                continue
            }
            val jobId = sidecar.jobId
            if (jobId == null) {
                analytics.track("expert_shield_upload_dropped", mapOf("reason" to "clip_sidecar_no_job"))
                store.delete(clip.filePath)
                continue
            }
            val bytes = withContext(dispatchers.io) { fileReader.read(clip.filePath) }
            if (bytes == null) {
                analytics.track("expert_shield_upload_dropped", mapOf("reason" to "clip_sweep_unreadable"))
                store.delete(clip.filePath)
                continue
            }
            // Original timestamp: a clip the live path already uploaded then failed to delete would
            // otherwise re-upload as a NEW clip instead of resolving to the server's 409.
            queue.enqueue(
                bookingId = jobId,
                encryptedAudioBytes = bytes,
                encryption = ShieldEncryptionMetadata(sidecar.wrappedKey, sidecar.iv, sidecar.authTag),
                durationSeconds = sidecar.durationSec,
                isSos = sidecar.isSos,
                timestamp = sidecar.createdAt,
            )
            analytics.track("expert_shield_clip_swept", mapOf("booking_id" to jobId, "is_sos" to sidecar.isSos))
            store.delete(clip.filePath)
        }
    }

    private suspend fun handleEncryptedAudio(event: ShieldEvent.EncryptedAudio) {
        // ECPO-986: the clip's own stamp wins — a receipt-time lookup drifts, the stamp can't. Latch is
        // the fallback when the session armed without an id.
        val jobId = event.jobId ?: currentJobId() ?: run {
            // No active job → drop (matches Flutter). Surface it, and discard the plugin-held AES key so a
            // raw per-clip key isn't retained for a clip we'll never upload (parity with the unreadable branch).
            analytics.track("expert_shield_upload_dropped", mapOf("reason" to "job_id_null_at_receipt"))
            runCatching { shield.discardAESKey() }
            // Delete the orphan too (#C6): key discarded, never uploaded, no sweeper — same as the
            // unreadable branch, so it doesn't accumulate on disk.
            runCatching { withContext(dispatchers.io) { fileReader.delete(event.filePath) } }
            return
        }
        try {
            // Bounded retry before giving up: a transient read miss (plugin still flushing, momentary I/O
            // pressure) would otherwise permanently drop a clip that reads fine moments later — worst for
            // SOS evidence audio. Only a persistent miss falls through to the drop.
            val bytes = readWithRetry(event.filePath) ?: run {
                analytics.track("expert_shield_upload_dropped", mapOf("reason" to "file_unreadable"))
                shield.discardAESKey()
                // Delete the orphan too (#C6). The key is gone, no retry path owns this clip, and no
                // sweeper reclaims it — so leaving the .enc on disk accumulates unbounded, unreadable
                // files. Best-effort: a delete failure is itself a read-miss symptom, nothing to do.
                runCatching { withContext(dispatchers.io) { fileReader.delete(event.filePath) } }
                return
            }
            val wrappedKey = keyWrapper.wrapAesKey(event.aesSecretKey)
            val metadata = ShieldEncryptionMetadata(encryptedKey = wrappedKey, iv = event.iv, authTag = event.authTag)
            queue.enqueue(
                bookingId = jobId,
                encryptedAudioBytes = bytes,
                encryption = metadata,
                durationSeconds = event.durationSec.takeIf { it > 0 } ?: recordingDurationSecs(),
                isSos = isSos(),
                isCompressed = true,
            )
            shield.discardAESKey()
            withContext(dispatchers.io) { fileReader.delete(event.filePath) }
        } catch (e: CancellationException) {
            throw e
        } catch (e: Throwable) {
            crashReporter.report(e, mapOf("op" to "shield_upload_enqueue", "file" to event.filePath))
        }
    }

    // Bounded read retry (transient-miss recovery). NOTE: this recovers a clip whose first read failed but
    // is still on disk; it does NOT sweep clips already orphaned before this process (that needs a
    // plugin-side clip-dir enumeration seam — a scoped follow-up, tracked separately).
    private suspend fun readWithRetry(path: String): ByteArray? {
        repeat(READ_RETRY_MAX) { attempt ->
            withContext(dispatchers.io) { fileReader.read(path) }?.let { return it }
            if (attempt < READ_RETRY_MAX - 1) delay(READ_RETRY_DELAY_MS)
        }
        return null
    }

    /**
     * Fallback only — the clip's own cadence (event.durationSec) wins. These two keys can't express the
     * plugin's three tiers, so a normal clip recorded on `expert_shield_manual_duration_secs` was being
     * reported as `expert_shield_duration_secs`. Kept for clips from a plugin that doesn't stamp it.
     */
    private suspend fun recordingDurationSecs(): Int =
        if (isSos()) remoteConfig.getInt(RC_SOS_DURATION, DEFAULT_SOS_DURATION)
        else remoteConfig.getInt(RC_DURATION, DEFAULT_DURATION)

    private companion object {
        const val RC_DURATION = "expert_shield_duration_secs"
        const val RC_SOS_DURATION = "expert_shield_sos_duration_secs"
        const val DEFAULT_DURATION = 5
        const val DEFAULT_SOS_DURATION = 10
        const val READ_RETRY_MAX = 3          // ~600ms total with the 300ms backoff
        const val READ_RETRY_DELAY_MS = 300L
    }
}
