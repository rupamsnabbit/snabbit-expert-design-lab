package com.snabbit.runner.shared.features.gamification.data

import com.snabbit.runner.shared.core.CrashReporter
import com.snabbit.runner.shared.core.CurrentTimeMs
import com.snabbit.runner.shared.core.FakeLogger
import com.snabbit.runner.shared.core.runnerstate.RunnerStateStore
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

@OptIn(ExperimentalCoroutinesApi::class)
class GamificationProjectorTest {

    /** Fixed clock so sheet-warning staleness is deterministic. */
    private val fixedNowMs = 1_752_364_800_000L // 2025-07-13T00:00:00Z-ish

    private fun setup(scope: TestScope): Pair<RunnerStateStore, GamificationProjector> {
        val store = RunnerStateStore(FakeLogger())
        val projector = GamificationProjector(
            store = store,
            scope = scope.backgroundScope,
            currentTimeMs = CurrentTimeMs { fixedNowMs },
            crashReporter = CrashReporter { _, _ -> },
        )
        return store to projector
    }

    @Test
    fun seedsEmptyState_beforeAnyEnvelope() = runTest {
        val (_, projector) = setup(this)
        runCurrent()
        assertTrue(projector.state.value.nudges.isEmpty())
        assertEquals(0, projector.state.value.coinsTotal)
    }

    @Test
    fun foldsTopLevelSiblings_fromEnvelope() = runTest {
        val (store, projector) = setup(this)
        // gold_coins_total + sheet_warnings ride at the TOP LEVEL, next to
        // widget_name/widget_data — the siblings RunnerState alone would drop.
        store.pushState(
            """
            {"widget_name":"RUNNER_LOGIN_HOTSPOT","widget_data":{},
             "gold_coins_total":30,"red_cards_total":2,
             "sheet_warnings":[{"lifecycle_action_type":"EMERGENCY_LOGOUT",
               "cta_overrides":[{"cta_id":"logout","red_cards":1}]}]}
            """.trimIndent(),
        )
        runCurrent()
        val state = projector.state.value
        assertEquals(30, state.coinsTotal)
        assertEquals(2, state.redCardsTotal)
        assertEquals(1, state.sheetWarnings.size)
    }

    @Test
    fun foldsNudges_fromWidgetData() = runTest {
        val (store, projector) = setup(this)
        store.pushState(
            """
            {"widget_name":"RUNNER_LOGIN_HOTSPOT","widget_data":{
               "pre_action_nudges":[{"lifecycle_action_type":"EARLY_LOGIN","nudge_kind":"risk",
                 "icon_url":"https://x/i.png","label":{"key":"k","default_text":"d"},
                 "cta_overrides":[{"cta_id":"login","red_cards":1}]}]}}
            """.trimIndent(),
        )
        runCurrent()
        val state = projector.state.value
        assertEquals(1, state.nudges.size)
        assertEquals(1, state.ctaOverride("LOGIN")?.redCards)
    }
}
