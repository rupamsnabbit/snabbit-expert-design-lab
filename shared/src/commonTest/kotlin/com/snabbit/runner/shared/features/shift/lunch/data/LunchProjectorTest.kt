package com.snabbit.runner.shared.features.shift.lunch.data

import com.snabbit.runner.shared.core.FakeLogger
import com.snabbit.runner.shared.core.runnerstate.RunnerStateStore
import com.snabbit.runner.shared.features.shift.lunch.domain.model.LunchPhase
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.datetime.Instant
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertNull
import kotlin.test.assertTrue

@OptIn(ExperimentalCoroutinesApi::class)
class LunchProjectorTest {

    /** Route the never-completing `store.state.collect` through backgroundScope. */
    private fun setup(scope: TestScope): Pair<RunnerStateStore, LunchProjector> {
        val store = RunnerStateStore(FakeLogger())
        return store to LunchProjector(store, scope.backgroundScope, FakeLogger())
    }

    private fun epoch(iso: String) = Instant.parse(iso).toEpochMilliseconds()

    @Test fun nullEnvelope_yieldsNullPhase() = runTest {
        val (_, rm) = setup(this); runCurrent()
        assertNull(rm.phase.value)
    }

    @Test fun nonLunchWidget_yieldsNullPhase() = runTest {
        val (store, rm) = setup(this)
        store.pushState("""{"widget_name":"RUNNER_WAIT_HOTSPOT","widget_data":{}}""")
        runCurrent()
        assertNull(rm.phase.value)
    }

    @Test fun requestWidget_yieldsRequest() = runTest {
        val (store, rm) = setup(this)
        store.pushState("""{"widget_name":"LUNCH_REQUEST","widget_data":{}}""")
        runCurrent()
        assertEquals(LunchPhase.Request, rm.phase.value)
    }

    @Test fun cooldownWidget_resolvesEpochsAndTotal() = runTest {
        val (store, rm) = setup(this)
        store.pushState("""
            {"widget_name":"LUNCH_COOLDOWN","widget_data":{
              "cooldown_start_time":"2026-06-29T10:00:00Z","cooldown_duration":15,
              "start_time":"2026-06-29T10:15:00Z","duration":30}}
        """.trimIndent())
        runCurrent()
        val p = assertIs<LunchPhase.Cooldown>(rm.phase.value)
        assertEquals(epoch("2026-06-29T10:15:00Z"), p.cooldownEndMs) // start + 15 min
        assertEquals(epoch("2026-06-29T10:15:00Z"), p.breakStartMs)
        assertEquals(epoch("2026-06-29T10:45:00Z"), p.breakEndMs)    // start + 30 min
        assertEquals(30 * 60, p.breakTotalSec)
    }

    @Test fun activeWidget_resolvesThresholdsAndCooldownEnd() = runTest {
        val (store, rm) = setup(this)
        store.pushState("""
            {"widget_name":"LUNCH","widget_data":{
              "cooldown_start_time":"2026-06-29T10:00:00Z","cooldown_duration":2,
              "start_time":"2026-06-29T10:02:00Z","duration":30,
              "green_state_duration":30,"amber_state_duration":15,"red_state_duration":5}}
        """.trimIndent())
        runCurrent()
        val p = assertIs<LunchPhase.OnBreak>(rm.phase.value)
        assertEquals(epoch("2026-06-29T10:02:00Z"), p.cooldownEndMs) // start + 2 min
        assertEquals(epoch("2026-06-29T10:00:00Z"), p.cooldownStartMs)
        assertEquals(epoch("2026-06-29T10:02:00Z"), p.breakStartMs)
        assertEquals(epoch("2026-06-29T10:32:00Z"), p.breakEndMs)
        assertEquals(30 * 60, p.greenStateSec)
        assertEquals(15 * 60, p.amberStateSec)
        assertEquals(5 * 60, p.redStateSec)
    }

    @Test fun activeWidget_withoutCooldown_collapsesCooldownToBreakStart() = runTest {
        val (store, rm) = setup(this)
        store.pushState("""
            {"widget_name":"LUNCH","widget_data":{
              "start_time":"2026-06-29T10:00:00Z","duration":30}}
        """.trimIndent())
        runCurrent()
        val p = assertIs<LunchPhase.OnBreak>(rm.phase.value)
        assertEquals(p.breakStartMs, p.cooldownEndMs)
        assertNull(p.cooldownStartMs)
    }

    /**
     * maestro-core serialises `current_state` timestamps with `.isoformat()` —
     * naive (no `Z`/offset), e.g. `2026-06-29T21:39:00.511910`. `Instant.parse`
     * rejects these; the read model must fall back to `LocalDateTime` so the
     * CMP home renders the break (the old Flutter home does, via Dart's lenient
     * `DateTime.parse`).
     */
    @Test fun activeWidget_naiveIsoStartTime_resolvesPhase() = runTest {
        val (store, rm) = setup(this)
        store.pushState("""
            {"widget_name":"LUNCH","widget_data":{
              "start_time":"2026-06-29T21:39:00.472071","duration":30}}
        """.trimIndent())
        runCurrent()
        assertIs<LunchPhase.OnBreak>(rm.phase.value)
    }

    @Test fun missingStartTime_yieldsNullPhase() = runTest {
        val (store, rm) = setup(this)
        store.pushState("""{"widget_name":"LUNCH","widget_data":{"duration":30}}""")
        runCurrent()
        assertNull(rm.phase.value)
    }

    @Test fun malformedStartTime_yieldsNullPhase() = runTest {
        val (store, rm) = setup(this)
        store.pushState("""
            {"widget_name":"LUNCH","widget_data":{"start_time":"not-a-date","duration":30}}
        """.trimIndent())
        runCurrent()
        assertNull(rm.phase.value)
    }

    @Test fun newEnvelopeReplacesPhase() = runTest {
        val (store, rm) = setup(this)
        store.pushState("""{"widget_name":"LUNCH_REQUEST","widget_data":{}}""")
        runCurrent()
        assertEquals(LunchPhase.Request, rm.phase.value)
        store.pushState("""{"widget_name":"RUNNER_WAIT_HOTSPOT","widget_data":{}}""")
        runCurrent()
        assertNull(rm.phase.value)
    }

    /**
     * Regression: `minutes()` used `intOrNull`, which returns null for a
     * float-formatted number — so the `duration: 30.0` this backend actually sends
     * (see ShiftProjector's `doubleOrNull` and its comment) silently became 0.
     * Every downstream band collapsed: breakEndMs == breakStartMs, instant expiry
     * re-poll, NaN ring on LunchActiveCard.
     */
    @Test fun floatFormattedDuration_parsesAsMinutes_notZero() = runTest {
        val (store, rm) = setup(this)
        store.pushState("""
            {"widget_name":"LUNCH","widget_data":{
              "start_time":"2026-06-29T10:00:00Z","duration":30.0}}
        """.trimIndent())
        runCurrent()
        val p = assertIs<LunchPhase.OnBreak>(rm.phase.value)
        assertEquals(30 * 60, p.breakTotalSec)
    }

    @Test fun floatFormattedCooldownDuration_parsesAsMinutes_notZero() = runTest {
        val (store, rm) = setup(this)
        store.pushState("""
            {"widget_name":"LUNCH_COOLDOWN","widget_data":{
              "cooldown_start_time":"2026-06-29T10:00:00Z","cooldown_duration":15.0,
              "start_time":"2026-06-29T10:15:00Z","duration":30.0}}
        """.trimIndent())
        runCurrent()
        val p = assertIs<LunchPhase.Cooldown>(rm.phase.value)
        assertEquals(30 * 60, p.breakTotalSec)
    }

    /** A present-but-garbage duration still falls back to 0, but is now logged
     *  rather than silently swallowed. */
    @Test fun unparseableDuration_defaultsToZero_andLogs() = runTest {
        val logger = FakeLogger()
        val store = RunnerStateStore(FakeLogger())
        val rm = LunchProjector(store, backgroundScope, logger)
        store.pushState("""
            {"widget_name":"LUNCH","widget_data":{
              "start_time":"2026-06-29T10:00:00Z","duration":"abc"}}
        """.trimIndent())
        runCurrent()
        val p = assertIs<LunchPhase.OnBreak>(rm.phase.value)
        assertEquals(0, p.breakTotalSec)
        assertTrue(logger.entries.any { it.message.contains("unparseable minutes") })
    }
}
