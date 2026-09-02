package com.snabbit.runner.shared.features.kavach.shield.data.upload

import com.snabbit.runner.shared.core.AppDispatchers
import com.snabbit.runner.shared.core.CrashReporter
import com.snabbit.runner.shared.core.CurrentTimeMs
import com.snabbit.runner.shared.core.analytics.AnalyticsTracker
import com.snabbit.runner.shared.features.kavach.shield.data.db.SelectEligibleMeta
import com.snabbit.runner.shared.features.kavach.shield.data.db.ShieldDatabase
import com.snabbit.runner.shared.features.kavach.shield.domain.upload.ShieldSyncScheduler
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.withContext
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kotlin.concurrent.Volatile

/**
 * Durable upload outbox (Step 7.3) — 1:1 with the Flutter `ShieldUploadQueue`. Each row holds the
 * encrypted audio BLOB + the RSA-wrapped encryption metadata (JSON, built by the caller). [enqueue]
 * stores + evicts (TTL + cap), then kicks a drain; [processQueue] drains oldest-first past the
 * backoff gate, running the 3-step upload via [uploadApi] (409 = already uploaded → delete).
 * Transport failures retry with exponential backoff up to 5×, then the clip is dropped.
 *
 * ⚠ The connectivity/on-resume trigger + a start() flush are lifecycle concerns (like the
 * coordinator's start()) — call [processQueue] from that hook (follow-up). Owns a long-lived [scope].
 */
class ShieldUploadQueue(
    private val db: ShieldDatabase,
    private val uploadApi: ShieldUploadApi,
    private val currentTimeMs: CurrentTimeMs,
    private val analytics: AnalyticsTracker,
    private val dispatchers: AppDispatchers,
    private val crashReporter: CrashReporter,
    /** Null on iOS / standalone: no out-of-band retry, behaviour as before this existed. */
    private val syncScheduler: ShieldSyncScheduler? = null,
) {
    private val queries get() = db.shieldUploadQueries
    private val json = Json { ignoreUnknownKeys = true }
    private val scope = CoroutineScope(SupervisorJob() + dispatchers.io)

    private val processing = Mutex()

    @Volatile
    private var pendingRetrigger = false

    /** Store one encrypted clip (caller supplies the RSA-wrapped [encryption]) + kick a drain. */
    suspend fun enqueue(
        bookingId: Int,
        encryptedAudioBytes: ByteArray,
        encryption: ShieldEncryptionMetadata,
        durationSeconds: Int,
        isSos: Boolean,
        isCompressed: Boolean = true,
        /** A swept clip re-enters with its ORIGINAL timestamp, so the server's dedupe still recognises it. */
        timestamp: Long? = null,
    ) {
        val now = currentTimeMs()
        val clipTimestamp = timestamp ?: now
        val metaJson = json.encodeToString(
            StoredEncryption(encryption.encryptedKey, encryption.iv, encryption.authTag, encryption.keyVersion, isCompressed),
        )
        withContext(dispatchers.io) {
            queries.insert(
                booking_id = bookingId.toLong(),
                timestamp = clipTimestamp,
                encrypted_audio_bytes = encryptedAudioBytes,
                encryption_metadata_json = metaJson,
                duration_seconds = durationSeconds.toLong(),
                is_sos = if (isSos) 1L else 0L,
                created_at = now,
            )
            enforceCap(now)
        }.let { reaped ->
            if (reaped.byTtl > 0) reportTtlReap(reaped.byTtl)
            if (reaped.byCap > 0) reportCapEviction(reaped.byCap)
        }
        // Guard the fire-and-forget kick: processQueue()'s SQLDelight reads can throw (disk full/
        // locked); uncaught in this launch → crash. The init-flush guards the same way (#R-D).
        scope.launch { runCatching { processQueue() } }
    }

    /**
     * Drain eligible rows. Single-flight; a concurrent call sets a retrigger the running pass
     * honors. The retrigger is re-checked AFTER releasing the lock (not before) so a flag set in
     * the check→unlock window isn't lost — on a multi-threaded dispatcher that window is real
     * (mirrors Flutter's release-then-recheck, which is atomic only on its single-threaded loop).
     */
    suspend fun processQueue() {
        while (true) {
            if (!processing.tryLock()) {
                // Another pass holds the lock; signal it — it re-checks after unlock (below).
                pendingRetrigger = true
                return
            }
            try {
                do {
                    pendingRetrigger = false
                    drainOnce()
                } while (pendingRetrigger)
            } finally {
                processing.unlock()
            }
            // A retrigger set between the last in-lock check and unlock would otherwise be stranded.
            if (!pendingRetrigger) {
                // Rows left behind (backoff, or a preflight denial that stopped the pass) have nothing
                // else to re-drive them — without this they waited for the next job's first clip.
                if (hasPending()) syncScheduler?.schedule()
                return
            }
        }
    }

    /** True while any row is still unsent — drives the scheduler's stop-when-empty decision. */
    suspend fun hasPending(): Boolean =
        withContext(dispatchers.io) { queries.count().executeAsOne() > 0L }

    /** Clear everything — 401 / logout (prevents cross-user data leakage). */
    suspend fun clearAll() {
        withContext(dispatchers.io) { queries.deleteAll() }
    }

    private suspend fun drainOnce() {
        val now = currentTimeMs()
        // TTL here as well as on enqueue. backOffWithoutSpendingBudget deliberately leaves retry_count
        // alone, so a row whose confirm keeps getting skipped never reaches MAX_RETRIES and retryOrDrop
        // never reaps it. With the TTL running only on enqueue, that row outlived the queue whenever the
        // runner stopped producing clips. NOT the count cap — dropping newest-over-cap mid-drain would
        // discard clips the pass was about to upload.
        reapExpired(now)
        // Metadata-only projection — each clip's BLOB is loaded lazily per row in uploadRow.
        val rows = withContext(dispatchers.io) { queries.selectEligibleMeta(now).executeAsList() }
        for (row in rows) {
            val meta = runCatching { json.decodeFromString<StoredEncryption>(row.encryption_metadata_json) }
                .onFailure { crashReporter.report(ShieldUploadException(it), mapOf("op" to "parse_metadata", "id" to row.id.toString())) }
                .getOrNull()
            if (meta == null) {
                deleteRow(row.id) // corrupt row → drop (reported above), never stall the queue
                continue
            }
            // Stop the pass on a preflight denial — every remaining row would hit the same block.
            if (!uploadRow(row, meta)) return
        }
    }

    /** @return false when nothing can be sent right now (preflight denied) — the caller stops the pass. */
    private suspend fun uploadRow(row: SelectEligibleMeta, meta: StoredEncryption): Boolean {
        val bookingId = row.booking_id.toInt()
        val isSos = row.is_sos == 1L
        try {
            val presigned = uploadApi.getPresignedUrl(bookingId, row.timestamp, isSos)
            val url = when (presigned) {
                is UploadOutcome.Conflict -> {
                    analytics.track("expert_shield_upload_success", mapOf("booking_id" to bookingId, "reason" to "already_uploaded"))
                    deleteRow(row.id); return true // already on the server
                }
                is UploadOutcome.Error -> { retryOrDrop(row); return true }
                // Nothing was sent (no token / offline) — keep the row's full retry budget and stop here.
                is UploadOutcome.Skipped -> return false
                is UploadOutcome.Ok -> presigned.value
            }
            // Load the BLOB lazily — only now, for a row we're actually uploading (not held for the
            // whole eligible set). A row deleted between the meta select and here → drop, don't retry.
            val bytes = withContext(dispatchers.io) { queries.selectBytesById(row.id).executeAsOneOrNull() }
                ?: run { deleteRow(row.id); return true }
            if (!uploadApi.uploadToS3(url.url, bytes, url.contentType)) {
                retryOrDrop(row)
                return true
            }
            val confirm = uploadApi.confirmUpload(
                jobId = bookingId,
                timestamp = row.timestamp,
                s3Key = url.s3Key,
                isSos = isSos,
                encryption = ShieldEncryptionMetadata(meta.encryptedKey, meta.iv, meta.authTag, meta.keyVersion),
                durationSeconds = row.duration_seconds.toInt(),
                isCompressed = meta.isCompressed,
            )
            when (confirm) {
                is UploadOutcome.Error -> retryOrDrop(row)
                // Confirm never left the device. Keep the retry budget (nothing failed) but push the
                // next attempt out — otherwise the row stays eligible and every pass re-PUTs the whole
                // clip to S3. There's no server record yet, so no 409 will resolve it for us. Preflight
                // is denied, so stop the pass here as well.
                is UploadOutcome.Skipped -> { backOffWithoutSpendingBudget(row); return false }
                else -> {
                    analytics.track("expert_shield_upload_success", mapOf("booking_id" to bookingId, "is_sos" to isSos, "retry_count" to row.retry_count.toInt(), "clip_size_bytes" to bytes.size))
                    deleteRow(row.id) // Ok or 409 → done
                }
            }
        } catch (e: CancellationException) {
            throw e
        } catch (e: Throwable) {
            crashReporter.report(ShieldUploadException(e), mapOf("op" to "row_exception", "id" to row.id.toString()))
            retryOrDrop(row)
        }
        return true
    }

    /** Defer without incrementing retry_count — for a step that never left the device. */
    private suspend fun backOffWithoutSpendingBudget(row: SelectEligibleMeta) {
        withContext(dispatchers.io) {
            queries.reschedule(retryCount = row.retry_count, nextAttemptAt = currentTimeMs() + BASE_BACKOFF_MS, id = row.id)
        }
    }

    private suspend fun retryOrDrop(row: SelectEligibleMeta) {
        val next = row.retry_count + 1
        if (next >= MAX_RETRIES) {
            crashReporter.report(
                ShieldUploadException(IllegalStateException("max_retries_exhausted")),
                mapOf("op" to "drop", "id" to row.id.toString()),
            )
            analytics.track("expert_shield_upload_dropped", mapOf("reason" to "clip_max_retries_exceeded", "booking_id" to row.booking_id.toInt()))
            deleteRow(row.id)
        } else {
            val nextAttemptAt = currentTimeMs() + backoffMs(next.toInt())
            withContext(dispatchers.io) { queries.reschedule(retryCount = next, nextAttemptAt = nextAttemptAt, id = row.id) }
        }
    }

    private suspend fun deleteRow(id: Long) {
        withContext(dispatchers.io) { queries.deleteById(id) }
    }

    /**
     * TTL (7-day) + count cap (20); SOS + newest survive — matches Flutter `_enforceQueueCap`.
     * @return how many rows each policy removed (the caller reports both).
     */
    private fun enforceCap(now: Long): Reaped =
        queries.transactionWithResult {
            val byTtl = deleteExpiredLocked(now)
            val ids = queries.selectIdsByPriority().executeAsList()
            val overCap = ids.drop(MAX_PENDING)
            overCap.forEach { queries.deleteById(it) }
            Reaped(byTtl = byTtl, byCap = overCap.size)
        }

    /** Rows one [enforceCap] pass removed, split by which retention policy took them. */
    private data class Reaped(val byTtl: Int, val byCap: Int)

    /** TTL-only sweep for the drain path. */
    private suspend fun reapExpired(now: Long) {
        val reaped = withContext(dispatchers.io) {
            queries.transactionWithResult { deleteExpiredLocked(now) }
        }
        if (reaped > 0) reportTtlReap(reaped)
    }

    /** A dropped clip is lost audio — never let the TTL take one silently. */
    private fun reportTtlReap(count: Int) {
        analytics.track("expert_shield_upload_dropped", mapOf("reason" to "clip_ttl_expired", "count" to count))
    }

    /** Same reasoning as [reportTtlReap] — an over-cap drop is lost audio too, just at the other door. */
    private fun reportCapEviction(count: Int) {
        analytics.track("expert_shield_upload_dropped", mapOf("reason" to "cap_exceeded", "count" to count))
    }

    /** Caller must already hold a transaction. @return how many rows the TTL removed. */
    private fun deleteExpiredLocked(now: Long): Int {
        val before = queries.count().executeAsOne()
        queries.deleteExpired(now - MAX_AGE_MS)
        return (before - queries.count().executeAsOne()).toInt()
    }

    /** 5s · 2^(attempt-1), capped at 30 min. */
    private fun backoffMs(attempt: Int): Long =
        minOf(BASE_BACKOFF_MS * (1L shl (attempt - 1)), MAX_BACKOFF_MS)

    @Serializable
    private data class StoredEncryption(
        @SerialName("encrypted_key") val encryptedKey: String,
        val iv: String,
        @SerialName("auth_tag") val authTag: String,
        @SerialName("key_version") val keyVersion: String = "v1",
        @SerialName("is_compressed") val isCompressed: Boolean = true,
    )

    private companion object {
        const val MAX_RETRIES = 5L
        const val BASE_BACKOFF_MS = 5_000L
        const val MAX_BACKOFF_MS = 30L * 60L * 1000L
        const val MAX_PENDING = 20
        const val MAX_AGE_MS = 7L * 24L * 60L * 60L * 1000L
    }
}
