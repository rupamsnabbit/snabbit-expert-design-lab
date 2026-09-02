package com.snabbit.runner.shared.core.appconfig

import com.snabbit.runner.shared.core.FakeLogger
import kotlinx.serialization.json.JsonPrimitive
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * Pins [AppConfigStore]'s bridge contract (mirrors `RunnerStateStore`'s):
 * write-from-Dart never throws, malformed pushes keep the last good
 * document, and the flow replays to late collectors via [AppConfigStore.snapshot].
 */
class AppConfigStoreTest {

    @Test
    fun snapshot_isNullBeforeFirstPush() {
        assertNull(AppConfigStore(FakeLogger()).snapshot())
    }

    @Test
    fun pushConfig_publishesTheDocument() {
        val store = AppConfigStore(FakeLogger())

        store.pushConfig("""{"job_support":{"options":[]},"other_key":1}""")

        assertEquals(JsonPrimitive(1), store.snapshot()?.get("other_key"))
    }

    @Test
    fun pushConfig_malformedJson_keepsLastGoodDocumentAndLogs() {
        val logger = FakeLogger()
        val store = AppConfigStore(logger)
        store.pushConfig("""{"good":true}""")

        store.pushConfig("""{"trunca""")

        assertEquals(JsonPrimitive(true), store.snapshot()?.get("good"))
        assertTrue(logger.entries.any { it.level == FakeLogger.Level.ERROR })
    }

    @Test
    fun pushConfig_nonObjectPayload_keepsLastGoodDocumentAndLogs() {
        val logger = FakeLogger()
        val store = AppConfigStore(logger)
        store.pushConfig("""{"good":true}""")

        store.pushConfig("""[1,2,3]""")

        assertEquals(JsonPrimitive(true), store.snapshot()?.get("good"))
        assertTrue(logger.entries.any { it.level == FakeLogger.Level.ERROR })
    }

    @Test
    fun pushConfig_replacesThePreviousDocument() {
        val store = AppConfigStore(FakeLogger())
        store.pushConfig("""{"v":1}""")

        store.pushConfig("""{"v":2}""")

        assertEquals(JsonPrimitive(2), store.snapshot()?.get("v"))
    }
}
