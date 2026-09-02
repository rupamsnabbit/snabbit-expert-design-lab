package com.snabbit.runner.shared.features.kavach.shield.domain.upload

import app.cash.sqldelight.driver.jdbc.sqlite.JdbcSqliteDriver
import com.safetykavach.shield.core.event.ShieldEvent
import com.snabbit.runner.shared.core.CrashReporter
import com.snabbit.runner.shared.core.CurrentTimeMs
import com.snabbit.runner.shared.features.kavach.FakeRemoteConfigGateway
import com.snabbit.runner.shared.features.kavach.FakeShieldController
import com.snabbit.runner.shared.features.kavach.FakeShieldFileReader
import com.snabbit.runner.shared.features.kavach.FakeShieldUploadApi
import com.snabbit.runner.shared.features.kavach.shield.data.upload.ShieldKeyWrapper
import com.snabbit.runner.shared.features.kavach.shield.data.upload.ShieldUploadQueue
import com.snabbit.runner.shared.features.kavach.shield.data.db.ShieldDatabase
import com.snabbit.runner.shared.features.kavach.testAppDispatchers
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.runTest
import kotlin.io.encoding.Base64
import kotlin.io.encoding.ExperimentalEncodingApi
import kotlin.test.Test
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/** Verifies the EncryptedAudio → wrap → enqueue → upload → discardAESKey → delete wire (Step 7.4). */
@OptIn(ExperimentalEncodingApi::class)
class ShieldUploadCoordinatorTest {

    private val testPem = """
        -----BEGIN PUBLIC KEY-----
        MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAvRf7oFqMsqqAgWIUr01P
        vVj9vBlaEaq2vsErNTZXHepVXZzBJfSlHih5LblNBgdbZLEE9YXt9rS0JZx3FNme
        Esi4qKqjipdWn2nTWujf2lllkDLt+9dehrajPHrzU7lVPs8ct52af3VE665NrJpI
        uWfA32OfTx2Jq7NfeEtvT81L/1K3t67oIwU36jtvUtAkPz8GptuBnR2koEYXu74I
        eANc+jxDC+5Jo6pKjk3ac1rwigY4vc6eX5o6guj+ZkPLV36V32FLS7rB3FbpBCAh
        XTEGcM/8PmJUj4Lw+/kNFMcjIpxGsaIHLSKricBMes3K/W1CZgLi2XCyeD5+S9L5
        pwIDAQAB
        -----END PUBLIC KEY-----
    """.trimIndent()

    private val reporter = CrashReporter { _, _ -> }
    private val shield = FakeShieldController()
    private val api = FakeShieldUploadApi()
    private val fileReader = FakeShieldFileReader(bytes = byteArrayOf(4, 5, 6))

    private fun newDb(): ShieldDatabase {
        val driver = JdbcSqliteDriver(JdbcSqliteDriver.IN_MEMORY)
        ShieldDatabase.Schema.create(driver)
        return ShieldDatabase(driver)
    }

    private fun coordinator(jobId: Int?): ShieldUploadCoordinator {
        val disp = testAppDispatchers(UnconfinedTestDispatcher())
        val queue = ShieldUploadQueue(newDb(), api, CurrentTimeMs { 1000L }, com.snabbit.runner.shared.features.kavach.FakeAnalyticsTracker(), disp, reporter)
        return ShieldUploadCoordinator(
            shield = shield,
            queue = queue,
            keyWrapper = ShieldKeyWrapper { testPem.encodeToByteArray() },
            fileReader = fileReader,
            remoteConfig = FakeRemoteConfigGateway(),
            currentJobId = { jobId },
            isSos = { false },
            analytics = com.snabbit.runner.shared.features.kavach.FakeAnalyticsTracker(),
            dispatchers = disp,
            crashReporter = reporter,
        )
    }

    private fun event() = ShieldEvent.EncryptedAudio(
        filePath = "/tmp/clip.enc",
        aesSecretKey = Base64.encode(ByteArray(32) { it.toByte() }),
        iv = "IV",
        authTag = "TAG",
    )

    @Test
    fun encryptedAudio_wrapsEnqueuesUploads_thenDiscardsKeyAndDeletesFile() = runTest {
        coordinator(jobId = 42) // self-starts collecting
        shield.eventsFlow.emit(event())

        assertEquals(1, api.presignedCalls)
        assertEquals(1, api.s3Calls)
        assertEquals(1, api.confirmCalls)
        assertContentEquals(byteArrayOf(4, 5, 6), api.lastPutBytes) // the file bytes reached S3
        assertTrue(shield.calls.contains("discardAESKey"))
        assertTrue(fileReader.deleted.contains("/tmp/clip.enc"))
    }

    // ECPO-986: the clip's stamped job wins over the receipt-time lookup. This is the reported bug —
    // a clip recorded under 42 that lands while the seam has already moved to 99 must still upload as 42.
    @Test
    fun encryptedAudio_stampedJobIdWins_overTheReceiptTimeSeam() = runTest {
        coordinator(jobId = 99)
        shield.eventsFlow.emit(event().copy(jobId = 42))

        assertEquals(42, api.lastPresignedJobId)
    }

    // The cadence escalates (monitoring → sos-pending → sos-confirmed) and the two RC keys here can't
    // express that, so a normal clip recorded on expert_shield_manual_duration_secs was reported as
    // expert_shield_duration_secs. The clip's own stamp is the truth.
    @Test
    fun encryptedAudio_stampedDurationWins_overTheRcFallback() = runTest {
        coordinator(jobId = 42)
        shield.eventsFlow.emit(event().copy(durationSec = 37))

        assertEquals(37, api.lastConfirmDurationSeconds)
    }

    // Unstamped (older plugin build) → the RC fallback still applies, so nothing regresses.
    @Test
    fun encryptedAudio_noStampedDuration_fallsBackToRc() = runTest {
        coordinator(jobId = 42)
        shield.eventsFlow.emit(event())

        assertEquals(5, api.lastConfirmDurationSeconds) // DEFAULT_DURATION
    }

    // No stamp (armed without an id, or a clip from an older plugin build) → fall back to the seam.
    @Test
    fun encryptedAudio_noStamp_fallsBackToTheSeam() = runTest {
        coordinator(jobId = 99)
        shield.eventsFlow.emit(event())

        assertEquals(99, api.lastPresignedJobId)
    }

    @Test
    fun encryptedAudio_noActiveJob_dropsClip() = runTest {
        coordinator(jobId = null)
        shield.eventsFlow.emit(event())

        assertEquals(0, api.presignedCalls)
        // #C6: drop the AES key AND delete the .enc. Key discarded, never uploaded, no sweeper — so
        // leaving the file accumulates unbounded orphans on disk.
        assertTrue(shield.calls.contains("discardAESKey"))
        assertTrue(fileReader.deleted.contains("/tmp/clip.enc"))
    }
}
