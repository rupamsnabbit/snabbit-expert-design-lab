package com.snabbit.runner.shared.core.localization

import com.snabbit.runner.shared.core.FakeLogger
import com.snabbit.runner.shared.core.CrashReporter
import com.snabbit.runner.shared.core.camera.fakes.FakeCrashReporter
import com.snabbit.runner.shared.core.camera.fakes.TestAppDispatchers
import com.snabbit.runner.shared.storage.InMemoryPreferenceStorage
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

class LocalizationStoreTest {

    // In-memory-only store (no persistence): the pull/lookup surface.
    private fun store() = LocalizationStore(FakeLogger(), CrashReporter { _, _ -> })

    private val json = Json { ignoreUnknownKeys = true; isLenient = true }

    @Test
    fun snapshot_isEmpty_beforePush() {
        val store = store()
        assertEquals(LocalizationSnapshot.EMPTY, store.snapshot())
        assertEquals(LocalizationSnapshot.EMPTY, store.state.value)
    }

    @Test
    fun getMessage_returnsFallback_beforePush() {
        // Un-fed store degrades to the caller's English default.
        assertEquals("Accept Job", store().getMessage("accept_job", "Accept Job"))
    }

    @Test
    fun pushMessages_populatesLookup_andLanguage() {
        val store = store()
        store.pushMessages("HINDI", """{"accept_job":"स्वीकार करें","deny":"मना करें"}""")
        assertEquals("स्वीकार करें", store.getMessage("accept_job", "Accept Job"))
        assertEquals("HINDI", store.snapshot().language)
    }

    @Test
    fun getMessage_returnsFallback_forMissingKey() {
        val store = store()
        store.pushMessages("ENGLISH", """{"accept_job":"Accept Job"}""")
        assertEquals("Deny", store.getMessage("deny", "Deny"))
    }

    @Test
    fun getMessage_isPassthrough_leavesDoubleBraceIntact() {
        // The bridge must NOT rewrite placeholders — single/double-brace
        // alignment is each consumer's concern, and the server copy embeds both
        // the ₹ symbol and a {{token}} verbatim.
        val store = store()
        store.pushMessages(
            "ENGLISH",
            """{"denial_loss_earnings":"You will miss ₹{{loss_amount}}"}""",
        )
        assertEquals(
            "You will miss ₹{{loss_amount}}",
            store.getMessage("denial_loss_earnings", "You will miss earnings"),
        )
    }

    @Test
    fun getFormattedMessage_substitutesDoubleBraceTokens() {
        val store = store()
        store.pushMessages(
            "ENGLISH",
            """{"denial_loss_earnings":"You will miss ₹{{loss_amount}}"}""",
        )
        assertEquals(
            "You will miss ₹1234",
            store.getFormattedMessage(
                "denial_loss_earnings",
                "You will miss earnings",
                mapOf("loss_amount" to "1234"),
            ),
        )
    }

    @Test
    fun getFormattedMessage_interpolatesFallback_whenKeyMissing() {
        // Before a push the fallback itself is interpolated (parity with Flutter).
        assertEquals(
            "Job extended by 15 min",
            store().getFormattedMessage(
                "job_extended",
                "Job extended by {{duration}}",
                mapOf("duration" to "15 min"),
            ),
        )
    }

    @Test
    fun pushMessages_malformedJson_keepsLastGood_logsError_andReportsToTelemetry() {
        val logger = FakeLogger()
        val crashReporter = FakeCrashReporter()
        val store = LocalizationStore(logger, crashReporter)
        store.pushMessages("ENGLISH", """{"accept_job":"Accept Job"}""")

        store.pushMessages("ENGLISH", "{ this is not json")

        // Last good snapshot preserved …
        assertEquals("Accept Job", store.getMessage("accept_job", "fallback"))
        // … the failure was logged at ERROR …
        assertTrue(logger.entries.any { it.level == FakeLogger.Level.ERROR })
        // … and reported to telemetry (base14 + Coralogix via CrashReporter).
        assertEquals(1, crashReporter.reported.size)
    }

    @Test
    fun pushMessages_skipsNonStringValues() {
        val store = store()
        store.pushMessages(
            "ENGLISH",
            """{"ok":"Accept","null_val":null,"nested":{"x":1}}""",
        )
        // A string value lands …
        assertEquals("Accept", store.getMessage("ok", "fb"))
        // … while null + nested values are dropped, so lookups fall back.
        assertEquals("fb", store.getMessage("null_val", "fb"))
        assertEquals("fb", store.getMessage("nested", "fb"))
    }

    @Test
    fun state_exposesLatestSnapshot() {
        val store = store()
        store.pushMessages("ENGLISH", """{"accept_job":"Accept Job"}""")
        assertEquals("Accept Job", store.state.value.messages["accept_job"])
    }

    // -- Persistence + cold-start seed --

    @Test
    fun pushMessages_persistsSnapshotToStorage() = runTest {
        val prefs = InMemoryPreferenceStorage()
        val store = LocalizationStore(
            FakeLogger(),
            FakeCrashReporter(),
            prefs,
            TestAppDispatchers(UnconfinedTestDispatcher(testScheduler)),
        )

        store.pushMessages("HINDI", """{"accept_job":"स्वीकार करें"}""")
        advanceUntilIdle() // let the fire-and-forget persist complete

        // Persisted as ONE JSON blob under one key (language + messages together).
        val raw = prefs.getString("localization_snapshot")
        assertNotNull(raw)
        val restored = json.decodeFromString<LocalizationSnapshot>(raw)
        assertEquals("HINDI", restored.language)
        assertEquals("स्वीकार करें", restored.messages["accept_job"])
    }

    @Test
    fun seedFromCache_rehydratesFromDisk_beforeFirstPush() = runTest {
        val prefs = InMemoryPreferenceStorage()
        // Pre-seed disk as an earlier session would have.
        prefs.putString(
            "localization_snapshot",
            json.encodeToString(
                LocalizationSnapshot("HINDI", mapOf("accept_job" to "स्वीकार करें")),
            ),
        )
        val store = LocalizationStore(
            FakeLogger(),
            FakeCrashReporter(),
            prefs,
            TestAppDispatchers(UnconfinedTestDispatcher(testScheduler)),
        )
        // Empty before seeding → English fallback.
        assertEquals("Accept Job", store.getMessage("accept_job", "Accept Job"))

        store.seedFromCache()

        // After seeding, the persisted copy is served.
        assertEquals("स्वीकार करें", store.getMessage("accept_job", "Accept Job"))
        assertEquals("HINDI", store.snapshot().language)
    }

    @Test
    fun seedFromCache_doesNotClobberFreshPush() = runTest {
        val prefs = InMemoryPreferenceStorage()
        prefs.putString(
            "localization_snapshot",
            json.encodeToString(LocalizationSnapshot("HINDI", mapOf("accept_job" to "पुराना"))),
        )
        val store = LocalizationStore(
            FakeLogger(),
            FakeCrashReporter(),
            prefs,
            TestAppDispatchers(UnconfinedTestDispatcher(testScheduler)),
        )

        // A fresh push lands before the cold seed runs — seed must not overwrite it.
        store.pushMessages("ENGLISH", """{"accept_job":"Accept Job"}""")
        store.seedFromCache()

        assertEquals("Accept Job", store.getMessage("accept_job", "fallback"))
        assertEquals("ENGLISH", store.snapshot().language)
    }

    @Test
    fun seedFromCache_withoutStorage_isNoop() = runTest {
        val store = LocalizationStore(FakeLogger(), FakeCrashReporter())
        store.seedFromCache()
        assertEquals(LocalizationSnapshot.EMPTY, store.snapshot())
    }
}
