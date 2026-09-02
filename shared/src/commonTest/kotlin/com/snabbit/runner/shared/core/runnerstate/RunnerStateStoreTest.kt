package com.snabbit.runner.shared.core.runnerstate

import com.snabbit.runner.shared.core.FakeLogger
import kotlinx.serialization.json.jsonPrimitive
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

class RunnerStateStoreTest {

    private fun store() = RunnerStateStore(FakeLogger())

    @Test
    fun snapshot_isNull_beforePush() {
        assertNull(store().snapshot())
        assertNull(store().state.value)
    }

    @Test
    fun pushState_populatesWidgetNameAndData() {
        val store = store()
        store.pushState(
            """{"widget_name":"RUNNER_JOB_IN_PROGRESS","widget_data":{"job_id":650}}""",
        )
        val state = store.snapshot()!!
        assertEquals("RUNNER_JOB_IN_PROGRESS", state.widgetName)
        assertEquals(
            "650",
            state.widgetData!!["job_id"]!!.jsonPrimitive.content,
        )
    }

    @Test
    fun pushState_ignoresUnknownTopLevelKeys() {
        // The current_state envelope carries a long tail (coins, sheet_warnings,
        // …) the bridge model doesn't declare — it must not break decoding.
        val store = store()
        store.pushState(
            """{"widget_name":"LUNCH","widget_data":{},"gold_coins_total":12,"sheet_warnings":[]}""",
        )
        assertEquals("LUNCH", store.snapshot()!!.widgetName)
    }

    @Test
    fun pushState_exposesTopLevelEnvelopeSiblings() {
        // Read models (e.g. gamification) need siblings that live NEXT TO
        // widget_name/widget_data — the typed RunnerState drops them, but the
        // raw envelope must preserve them.
        val store = store()
        store.pushState(
            """{"widget_name":"RUNNER_LOGIN_HOTSPOT","widget_data":{},"gold_coins_total":30,"sheet_warnings":[]}""",
        )
        val envelope = store.envelope.value!!
        assertEquals("30", envelope["gold_coins_total"]!!.jsonPrimitive.content)
        assertTrue(envelope.containsKey("sheet_warnings"))
    }

    @Test
    fun envelope_isNull_beforePush() {
        assertNull(store().envelope.value)
    }

    @Test
    fun pushState_malformedJson_keepsLastGoodEnvelope() {
        val store = store()
        store.pushState("""{"widget_name":"RUNNER_NEW_JOB","widget_data":{},"gold_coins_total":5}""")
        store.pushState("{ not json")
        assertEquals("5", store.envelope.value!!["gold_coins_total"]!!.jsonPrimitive.content)
    }

    @Test
    fun pushState_allowsNullWidgetData() {
        val store = store()
        store.pushState("""{"widget_name":"RUNNER_LOGOUT"}""")
        val state = store.snapshot()!!
        assertEquals("RUNNER_LOGOUT", state.widgetName)
        assertNull(state.widgetData)
    }

    @Test
    fun pushState_malformedJson_keepsLastGoodState_andLogsError() {
        val logger = FakeLogger()
        val store = RunnerStateStore(logger)
        store.pushState("""{"widget_name":"RUNNER_NEW_JOB","widget_data":{}}""")

        store.pushState("{ this is not json")

        // Last good state preserved …
        assertEquals("RUNNER_NEW_JOB", store.snapshot()!!.widgetName)
        // … and the failure was logged at ERROR.
        assertTrue(logger.entries.any { it.level == FakeLogger.Level.ERROR })
    }

    @Test
    fun state_exposesLatestValue() {
        val store = store()
        store.pushState("""{"widget_name":"SELFIE_CHECK","widget_data":{}}""")
        assertEquals("SELFIE_CHECK", store.state.value!!.widgetName)
    }

    @Test
    fun requestRefresh_invokesBoundBridge() {
        val store = store()
        var calls = 0
        store.bind { calls++ }

        store.requestRefresh()
        store.requestRefresh()

        assertEquals(2, calls)
    }

    @Test
    fun requestRefresh_isNoOp_whenUnbound() {
        // Compose VM may call before plugin attach or after detach — must not throw.
        store().requestRefresh()
    }

    @Test
    fun bind_null_clearsPreviousBridge() {
        val store = store()
        var calls = 0
        store.bind { calls++ }
        store.bind(null)

        store.requestRefresh()

        assertEquals(0, calls)
    }

    @Test
    fun onPostAction_invokesBoundBridge_withAction() {
        val store = store()
        val actions = mutableListOf<String>()
        store.bindPostAction { actions += it }

        store.onPostAction("attendance")
        store.onPostAction("checkout")

        assertEquals(listOf("attendance", "checkout"), actions)
    }

    @Test
    fun onPostAction_isNoOp_whenUnbound() {
        // Polling cohort / iOS / pre-attach: no engine bridge — must not throw.
        store().onPostAction("attendance")
    }

    @Test
    fun bindPostAction_null_clearsPreviousBridge() {
        val store = store()
        var calls = 0
        store.bindPostAction { calls++ }
        store.bindPostAction(null)

        store.onPostAction("attendance")

        assertEquals(0, calls)
    }
}
