package com.snabbit.runner.shared.features.kavach.shield.domain.upload

import app.cash.sqldelight.driver.jdbc.sqlite.JdbcSqliteDriver
import com.safetykavach.shield.recording.ClipSidecar
import com.safetykavach.shield.recording.ClipStore
import com.safetykavach.shield.recording.PendingClip
import com.snabbit.runner.shared.core.CrashReporter
import com.snabbit.runner.shared.core.CurrentTimeMs
import com.snabbit.runner.shared.features.kavach.FakeAnalyticsTracker
import com.snabbit.runner.shared.features.kavach.FakeRemoteConfigGateway
import com.snabbit.runner.shared.features.kavach.FakeShieldController
import com.snabbit.runner.shared.features.kavach.FakeShieldFileReader
import com.snabbit.runner.shared.features.kavach.FakeShieldUploadApi
import com.snabbit.runner.shared.features.kavach.shield.data.db.ShieldDatabase
import com.snabbit.runner.shared.features.kavach.shield.data.upload.ShieldKeyWrapper
import com.snabbit.runner.shared.features.kavach.shield.data.upload.ShieldUploadQueue
import com.snabbit.runner.shared.features.kavach.shield.data.upload.UploadOutcome
import com.snabbit.runner.shared.features.kavach.testAppDispatchers
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * The startup sweep: a `.enc` still on disk means the host never committed its row, so the clip must be
 * recovered from its sidecar rather than left to rot undecryptable.
 */
class ShieldClipSweepTest {

    private val reporter = CrashReporter { _, _ -> }
    private val analytics = FakeAnalyticsTracker()
    private val api = FakeShieldUploadApi()

    private class FakeClipStore(var clips: List<PendingClip>) : ClipStore {
        val deleted = mutableListOf<String>()
        override suspend fun listPendingClips() = clips
        override suspend fun delete(filePath: String) { deleted += filePath }
    }

    private fun sidecar(jobId: Int? = 650, createdAt: Long = 111L) = ClipSidecar(
        wrappedKey = "WRAPPED", iv = "IV", authTag = "TAG",
        jobId = jobId, isSos = true, durationSec = 10, createdAt = createdAt,
    )

    private fun newDb() = JdbcSqliteDriver(JdbcSqliteDriver.IN_MEMORY)
        .also { ShieldDatabase.Schema.create(it) }
        .let { ShieldDatabase(it) }

    private fun run(store: FakeClipStore, db: ShieldDatabase = newDb()) {
        val disp = testAppDispatchers(UnconfinedTestDispatcher())
        // Preflight-denied so swept rows stay in the DB and stay assertable.
        api.presignedResult = UploadOutcome.Skipped
        ShieldUploadCoordinator(
            shield = FakeShieldController(),
            queue = ShieldUploadQueue(db, api, CurrentTimeMs { 9_999L }, analytics, disp, reporter),
            keyWrapper = ShieldKeyWrapper { ByteArray(0) },
            fileReader = FakeShieldFileReader(bytes = byteArrayOf(1, 2, 3)),
            remoteConfig = FakeRemoteConfigGateway(),
            currentJobId = { null },
            isSos = { false },
            analytics = analytics,
            dispatchers = disp,
            crashReporter = reporter,
            clipStore = store,
        )
    }

    @Test
    fun strandedClipWithSidecar_isReEnqueuedAndFileRemoved() = runTest {
        val store = FakeClipStore(listOf(PendingClip("/clips/a.enc", sidecar())))
        val db = newDb()
        run(store, db)

        val row = db.shieldUploadQueries.selectEligible(Long.MAX_VALUE).executeAsList().single()
        assertEquals(650L, row.booking_id)
        assertEquals(1L, row.is_sos)
        assertEquals(10L, row.duration_seconds)
        // The sidecar's timestamp, NOT now(): a clip the live path already uploaded but failed to delete
        // must resolve to the server's 409 instead of re-uploading as a new clip.
        assertEquals(111L, row.timestamp)
        assertTrue(store.deleted.contains("/clips/a.enc"))
        assertTrue(analytics.names().contains("expert_shield_clip_swept"))
    }

    @Test
    fun missingSidecar_isDroppedAndCounted() = runTest {
        // No sidecar → the AES key is gone, so the clip can never be decrypted. Count it, don't hoard it.
        val store = FakeClipStore(listOf(PendingClip("/clips/b.enc", null)))
        val db = newDb()
        run(store, db)

        assertEquals(0L, db.shieldUploadQueries.count().executeAsOne())
        assertTrue(store.deleted.contains("/clips/b.enc"))
        assertEquals("clip_sidecar_missing", analytics.last("expert_shield_upload_dropped")?.props?.get("reason"))
    }

    @Test
    fun sidecarWithoutJobId_isDroppedAndCounted() = runTest {
        val store = FakeClipStore(listOf(PendingClip("/clips/c.enc", sidecar(jobId = null))))
        val db = newDb()
        run(store, db)

        assertEquals(0L, db.shieldUploadQueries.count().executeAsOne())
        assertEquals("clip_sidecar_no_job", analytics.last("expert_shield_upload_dropped")?.props?.get("reason"))
    }

    @Test
    fun noClipsOnDisk_sweepIsANoOp() = runTest {
        val store = FakeClipStore(emptyList())
        val db = newDb()
        run(store, db)

        assertEquals(0L, db.shieldUploadQueries.count().executeAsOne())
        assertTrue(store.deleted.isEmpty())
    }
}
