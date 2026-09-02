package com.snabbit.runner.shared.features.kavach.shield.data.upload

import app.cash.sqldelight.driver.jdbc.sqlite.JdbcSqliteDriver
import com.snabbit.runner.shared.core.CrashReporter
import com.snabbit.runner.shared.core.CurrentTimeMs
import com.snabbit.runner.shared.features.kavach.FakeAnalyticsTracker
import com.snabbit.runner.shared.features.kavach.FakeShieldUploadApi
import com.snabbit.runner.shared.features.kavach.shield.data.db.ShieldDatabase
import com.snabbit.runner.shared.features.kavach.shield.domain.upload.ShieldSyncScheduler
import com.snabbit.runner.shared.features.kavach.testAppDispatchers
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/** Outbox logic against a real in-memory SQLite DB: 3-step upload, 409, retry/backoff, cap, clear. */
class ShieldUploadQueueTest {

    private val reporter = CrashReporter { _, _ -> }
    private val encryption = ShieldEncryptionMetadata(encryptedKey = "EK", iv = "IV", authTag = "TAG")

    private fun newDb(): ShieldDatabase {
        val driver = JdbcSqliteDriver(JdbcSqliteDriver.IN_MEMORY)
        ShieldDatabase.Schema.create(driver)
        return ShieldDatabase(driver)
    }

    private val analytics = FakeAnalyticsTracker()

    /** Counts out-of-band drain requests — the retry driver that was missing entirely. */
    private class RecordingScheduler : ShieldSyncScheduler {
        var calls = 0
        var lastExpedite: Boolean? = null
        override fun schedule(expedite: Boolean) { calls++; lastExpedite = expedite }
    }

    private val scheduler = RecordingScheduler()

    private fun queue(db: ShieldDatabase, api: FakeShieldUploadApi, clock: () -> Long = { 1000L }) =
        ShieldUploadQueue(db, api, CurrentTimeMs { clock() }, analytics, testAppDispatchers(UnconfinedTestDispatcher()), reporter, scheduler)

    private fun count(db: ShieldDatabase) = db.shieldUploadQueries.count().executeAsOne()

    @Test
    fun enqueue_success_uploadsThenDeletesRow() = runTest {
        val db = newDb()
        val api = FakeShieldUploadApi()
        queue(db, api).enqueue(
            bookingId = 7, encryptedAudioBytes = byteArrayOf(1, 2, 3), encryption = encryption,
            durationSeconds = 30, isSos = true,
        )
        assertEquals(1, api.presignedCalls)
        assertEquals(1, api.s3Calls)
        assertEquals(1, api.confirmCalls)
        assertContentEquals(byteArrayOf(1, 2, 3), api.lastPutBytes)
        assertEquals("s3key", api.lastConfirmS3Key)
        assertEquals(true, api.lastConfirmIsSos)
        assertEquals(0L, count(db)) // deleted on success
    }

    @Test
    fun presignedConflict_deletesWithoutUploading() = runTest {
        val db = newDb()
        val api = FakeShieldUploadApi().apply { presignedResult = UploadOutcome.Conflict }
        queue(db, api).enqueue(1, byteArrayOf(9), encryption, 5, false)
        assertEquals(0, api.s3Calls)
        assertEquals(0, api.confirmCalls)
        assertEquals(0L, count(db)) // 409 = already uploaded → dropped
    }

    @Test
    fun transportError_retainsAndReschedules() = runTest {
        val db = newDb()
        val api = FakeShieldUploadApi().apply { presignedResult = UploadOutcome.Error }
        queue(db, api).enqueue(1, byteArrayOf(9), encryption, 5, false)
        assertEquals(0, api.s3Calls)
        assertEquals(1L, count(db)) // retained
        val row = db.shieldUploadQueries.selectEligible(Long.MAX_VALUE).executeAsList().single()
        assertEquals(1L, row.retry_count)
        assertEquals(1000L + 5_000L, row.next_attempt_at) // 5s backoff on attempt 1
    }

    // Preflight declined the presigned step: nothing was sent, so the row must keep its full retry
    // budget — five offline drains used to delete a clip that never left the device.
    @Test
    fun presignedSkipped_retainsRow_andSpendsNoBudget() = runTest {
        val db = newDb()
        val api = FakeShieldUploadApi().apply { presignedResult = UploadOutcome.Skipped }
        queue(db, api).enqueue(1, byteArrayOf(9), encryption, 5, false)
        assertEquals(0, api.s3Calls)
        val row = db.shieldUploadQueries.selectEligible(Long.MAX_VALUE).executeAsList().single()
        assertEquals(0L, row.retry_count)
        assertEquals(0L, row.next_attempt_at) // untouched — still immediately eligible
    }

    // Preflight declined only the confirm: S3 already has the bytes, so the row is deferred rather than
    // left eligible — otherwise every pass re-PUTs the whole clip, and no 409 exists to stop it.
    @Test
    fun confirmSkipped_backsOffWithoutSpendingBudget() = runTest {
        val db = newDb()
        val api = FakeShieldUploadApi().apply { confirmResult = UploadOutcome.Skipped }
        queue(db, api).enqueue(1, byteArrayOf(9), encryption, 5, false)
        assertEquals(1, api.s3Calls)
        assertEquals(1L, count(db)) // retained
        val row = db.shieldUploadQueries.selectEligible(Long.MAX_VALUE).executeAsList().single()
        assertEquals(0L, row.retry_count)            // nothing failed → budget intact
        assertEquals(1000L + 5_000L, row.next_attempt_at) // but deferred, so no re-PUT loop
    }

    @Test
    fun maxRetries_dropsRow() = runTest {
        val db = newDb()
        val api = FakeShieldUploadApi().apply { presignedResult = UploadOutcome.Error }
        var clock = 1000L
        val q = queue(db, api) { clock }
        q.enqueue(1, byteArrayOf(9), encryption, 5, false) // attempt 1 → retry_count 1
        repeat(4) {
            clock += 60L * 60L * 1000L // jump past any backoff (cap 30min)
            q.processQueue()
        }
        assertEquals(0L, count(db)) // 5th attempt hits MAX_RETRIES → dropped
    }

    @Test
    fun enforceCap_keepsTwenty() = runTest {
        val db = newDb()
        val api = FakeShieldUploadApi().apply { presignedResult = UploadOutcome.Error } // keep rows in-queue
        val q = queue(db, api)
        repeat(22) { q.enqueue(bookingId = it, encryptedAudioBytes = byteArrayOf(it.toByte()), encryption = encryption, durationSeconds = 1, isSos = false) }
        assertEquals(20L, count(db))
    }

    // An over-cap drop is lost audio just like a TTL reap — it must not be silent.
    @Test
    fun enforceCap_reportsTheEviction() = runTest {
        val db = newDb()
        val api = FakeShieldUploadApi().apply { presignedResult = UploadOutcome.Error } // keep rows in-queue
        val q = queue(db, api)
        fun fill(id: Int) = byteArrayOf(id.toByte())
        repeat(20) { q.enqueue(bookingId = it, encryptedAudioBytes = fill(it), encryption = encryption, durationSeconds = 1, isSos = false) }
        assertEquals(0, capEvictions().size) // sitting AT the cap drops nothing

        q.enqueue(bookingId = 20, encryptedAudioBytes = fill(20), encryption = encryption, durationSeconds = 1, isSos = false)
        assertEquals(1, capEvictions().size)
        assertEquals(1, capEvictions().single().props["count"])
    }

    private fun capEvictions() = analytics.tracked.filter {
        it.name == "expert_shield_upload_dropped" && it.props["reason"] == "cap_exceeded"
    }

    @Test
    fun clearAll_emptiesQueue() = runTest {
        val db = newDb()
        val api = FakeShieldUploadApi().apply { presignedResult = UploadOutcome.Error }
        val q = queue(db, api)
        q.enqueue(1, byteArrayOf(9), encryption, 5, false)
        assertEquals(1L, count(db))
        q.clearAll()
        assertEquals(0L, count(db))
    }

    // A confirm-Skipped row keeps its retry budget by design, so retryOrDrop never reaps it. With the
    // TTL running only on enqueue, that row outlived the queue once the runner stopped producing clips.
    @Test
    fun ttlExpiredRow_isReapedOnDrain_notOnlyOnEnqueue() = runTest {
        val db = newDb()
        val api = FakeShieldUploadApi().apply { confirmResult = UploadOutcome.Skipped }
        var clock = 1000L
        val q = queue(db, api) { clock }
        q.enqueue(1, byteArrayOf(9), encryption, 5, false)
        assertEquals(1L, count(db)) // retained, budget intact

        clock += 8L * 24L * 60L * 60L * 1000L // 8 days — past the 7-day TTL, with no further enqueue
        q.processQueue()

        assertEquals(0L, count(db))
        val dropped = analytics.last("expert_shield_upload_dropped")
        assertEquals("clip_ttl_expired", dropped?.props?.get("reason"))
        assertEquals(1, dropped?.props?.get("count"))
    }

    @Test
    fun ttlReap_doesNotTouchRowsInsideTheWindow() = runTest {
        val db = newDb()
        val api = FakeShieldUploadApi().apply { presignedResult = UploadOutcome.Error }
        var clock = 1000L
        val q = queue(db, api) { clock }
        q.enqueue(1, byteArrayOf(9), encryption, 5, false)

        clock += 6L * 24L * 60L * 60L * 1000L // 6 days — still inside the window
        q.processQueue()

        assertEquals(1L, count(db))
        assertEquals(null, analytics.last("expert_shield_upload_dropped"))
    }

    // The reported bug: a row left behind at job end had no driver, so it waited for the next job's
    // first clip to kick the queue.
    @Test
    fun rowsLeftBehind_scheduleAnOutOfBandDrain() = runTest {
        val db = newDb()
        val api = FakeShieldUploadApi().apply { presignedResult = UploadOutcome.Error }
        queue(db, api).enqueue(1, byteArrayOf(9), encryption, 5, false)

        assertEquals(1L, count(db))          // retained on backoff
        assertTrue(scheduler.calls > 0)      // and something will come back for it
    }

    @Test
    fun emptyQueue_schedulesNothing() = runTest {
        val db = newDb()
        val q = queue(db, FakeShieldUploadApi())
        q.enqueue(1, byteArrayOf(9), encryption, 5, false)   // uploads + deletes

        assertEquals(0L, count(db))
        q.processQueue()
        assertEquals(0, scheduler.calls)     // nothing pending → the worker must be allowed to stop
    }

    @Test
    fun explicitTimestamp_isPreservedForSweptClips() = runTest {
        val db = newDb()
        val api = FakeShieldUploadApi().apply { presignedResult = UploadOutcome.Error }
        queue(db, api).enqueue(1, byteArrayOf(9), encryption, 5, false, timestamp = 555L)

        val row = db.shieldUploadQueries.selectEligible(Long.MAX_VALUE).executeAsList().single()
        assertEquals(555L, row.timestamp)    // server dedupe key — must not be re-stamped
        assertEquals(1000L, row.created_at)  // TTL still measured from now
    }

    @Test
    fun hasPending_tracksTheOutbox() = runTest {
        val db = newDb()
        val api = FakeShieldUploadApi().apply { presignedResult = UploadOutcome.Error }
        val q = queue(db, api)
        assertEquals(false, q.hasPending())
        q.enqueue(1, byteArrayOf(9), encryption, 5, false)
        assertEquals(true, q.hasPending())
    }

    // Pass-driven reschedules must NOT expedite: REPLACE here would re-enqueue immediately after every
    // pass that left rows behind, i.e. a hot retry loop against the network.
    @Test
    fun passDrivenReschedule_doesNotExpedite() = runTest {
        val db = newDb()
        val api = FakeShieldUploadApi().apply { presignedResult = UploadOutcome.Error }
        queue(db, api).enqueue(1, byteArrayOf(9), encryption, 5, false)

        assertTrue(scheduler.calls > 0)
        assertEquals(false, scheduler.lastExpedite)
    }
}
