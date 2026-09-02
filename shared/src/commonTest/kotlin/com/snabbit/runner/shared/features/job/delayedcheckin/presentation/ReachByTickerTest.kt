package com.snabbit.runner.shared.features.job.delayedcheckin.presentation

import com.snabbit.runner.shared.features.job.delayedcheckin.domain.model.ReachBy
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.TestCoroutineScheduler
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue
import kotlin.time.Clock
import kotlin.time.Instant

/**
 * Virtual-time coverage for [ReachByTicker] — the ticking behaviour itself,
 * which [DelayedCheckinViewModelTest] never exercises (its `FakeClock` is only
 * ever read once per pushed payload; no `delay` ever runs there).
 *
 * The ticker is fully virtual-time testable: its `delay` rides the test
 * scheduler, and [SchedulerClock] derives `now()` from that same scheduler's
 * `currentTime` — so clock and delays advance in lockstep with `advanceTimeBy`,
 * no real sleeping. Pins the documented contract (class KDoc):
 *
 *  - immediate first emission, then once per second, decreasing toward the
 *    deadline; [ReachByTicker.signedStream] goes negative past it,
 *  - [ReachByTicker.stream] clamps at `ReachBy(0)` — never a negative — and
 *    NEVER completes: it keeps emitting `ReachBy(0)` once a second forever
 *    (termination is the collector's job),
 *  - emissions align to wall-clock second BOUNDARIES (a first partial delay,
 *    then a 1 s cadence) rather than a fixed 1000 ms after each emission,
 *  - each emission recomputes `deadline - now` from scratch — a wall-clock
 *    jump between emissions (process suspension) is reflected immediately,
 *    never accumulated around,
 *  - the Long→Int narrowing saturates at ±Int.MAX_VALUE for garbage deadlines
 *    instead of wrapping into a bogus small countdown.
 *
 * NOTE: `advanceUntilIdle` must never be used against these flows — they
 * perpetually reschedule a `delay`, so the scheduler never goes idle. All
 * stepping here is explicit `advanceTimeBy(...)` + `runCurrent()` (tasks
 * landing exactly on the advanced-to instant run in `runCurrent`), and
 * collectors ride `backgroundScope` so `runTest` cancels them at test end.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class ReachByTickerTest {

    /**
     * A [Clock] slaved to the test scheduler: `now()` = [baseEpochMillis] +
     * virtual time (+ any explicit [wallClockJumpMillis]) — the ticker's
     * `delay`s and its clock reads advance together under `advanceTimeBy`.
     */
    private class SchedulerClock(
        private val scheduler: TestCoroutineScheduler,
        private val baseEpochMillis: Long = 0L,
    ) : Clock {
        /** Extra wall-clock offset, bumped mid-test to simulate a suspension gap. */
        var wallClockJumpMillis: Long = 0L

        override fun now(): Instant =
            Instant.fromEpochMilliseconds(baseEpochMillis + scheduler.currentTime + wallClockJumpMillis)
    }

    /** Starts collecting, runs the immediate emission, cancels, returns it. */
    private fun <T> TestScope.firstEmission(flow: Flow<T>): T {
        val values = mutableListOf<T>()
        val job = backgroundScope.launch { flow.collect { values += it } }
        runCurrent()
        job.cancel()
        return values.first()
    }

    // ── Countdown cadence ─────────────────────────────────────────────────

    @Test
    fun signedStream_emitsImmediately_thenOncePerSecond_goingNegativePastDeadline() = runTest {
        val clock = SchedulerClock(testScheduler)
        val ticker = ReachByTicker(clock)
        val emissions = mutableListOf<Int>()
        backgroundScope.launch {
            ticker.signedStream(Instant.fromEpochMilliseconds(3_000)).collect { emissions += it }
        }

        // First emission is immediate — no virtual time has to pass.
        runCurrent()
        assertEquals(listOf(3), emissions)

        // Then exactly one emission per elapsed second, straight through the
        // deadline (t=3s → 0) and into signed overrun (-1, -2).
        repeat(5) {
            advanceTimeBy(1_000)
            runCurrent()
        }
        assertEquals(listOf(3, 2, 1, 0, -1, -2), emissions)
    }

    @Test
    fun stream_clampsAtZero_andKeepsEmittingZeroForever() = runTest {
        val clock = SchedulerClock(testScheduler)
        val ticker = ReachByTicker(clock)
        val emissions = mutableListOf<ReachBy>()
        val job = backgroundScope.launch {
            ticker.stream(Instant.fromEpochMilliseconds(2_000)).collect { emissions += it }
        }

        runCurrent()
        repeat(4) {
            advanceTimeBy(1_000)
            runCurrent()
        }

        // Clamped at the deadline: 2, 1, 0 — then it PARKS at 0 (t=3s, t=4s),
        // one emission per second, never a negative value.
        assertEquals(listOf(2, 1, 0, 0, 0), emissions.map { it.remainingSeconds })
        assertTrue(emissions.all { it.remainingSeconds >= 0 }, "stream must never emit a negative")

        // And the flow never completes past the deadline — termination is the
        // collector's job (the VM cancels collection), not the ticker's.
        assertTrue(job.isActive, "stream must keep running past the deadline")
    }

    // ── Wall-clock second alignment (anti-drift) ──────────────────────────

    @Test
    fun emissions_alignToWallClockSecondBoundaries_notFixedIntervalsAfterStart() = runTest {
        // Clock starts 400 ms PAST a second boundary → the first delay must be
        // sized to 600 ms (landing on epoch 1000), not a fixed 1000 ms.
        val clock = SchedulerClock(testScheduler, baseEpochMillis = 400L)
        val ticker = ReachByTicker(clock)
        val emissions = mutableListOf<Int>()
        backgroundScope.launch {
            ticker.signedStream(Instant.fromEpochMilliseconds(2_000)).collect { emissions += it }
        }

        runCurrent()
        assertEquals(1, emissions.size) // t=400: 1600 ms left → 1 (whole seconds)

        advanceTimeBy(599)
        runCurrent()
        assertEquals(1, emissions.size, "must still be waiting for the epoch-1000 boundary")

        advanceTimeBy(1)
        runCurrent()
        assertEquals(2, emissions.size, "second emission lands ON the second boundary (600 ms in)")

        // From the boundary on, the cadence is a clean 1 s.
        advanceTimeBy(999)
        runCurrent()
        assertEquals(2, emissions.size)
        advanceTimeBy(1)
        runCurrent()
        assertEquals(3, emissions.size)

        assertEquals(listOf(1, 1, 0), emissions) // t=400 (1.6s left), t=1000 (1s), t=2000 (0s)
    }

    // ── Recompute-from-scratch drift immunity ─────────────────────────────

    @Test
    fun signedStream_reflectsWallClockJumpImmediately_neverAccumulates() = runTest {
        val clock = SchedulerClock(testScheduler)
        val ticker = ReachByTicker(clock)
        val emissions = mutableListOf<Int>()
        backgroundScope.launch {
            ticker.signedStream(Instant.fromEpochMilliseconds(3_000)).collect { emissions += it }
        }
        runCurrent()
        assertEquals(listOf(3), emissions)

        // The wall clock jumps 10 s while the ticker sits in its delay (a
        // suspended process catching up). The next emission must recompute
        // `deadline - now` from scratch: 3s - 11s = -8 — NOT tick 3 → 2.
        clock.wallClockJumpMillis = 10_000L
        advanceTimeBy(1_000)
        runCurrent()
        assertEquals(listOf(3, -8), emissions)
    }

    // ── Saturating Long→Int narrowing ─────────────────────────────────────

    @Test
    fun narrowing_saturatesAtIntRange_forGarbageDeadlines() = runTest {
        val clock = SchedulerClock(testScheduler)
        val ticker = ReachByTicker(clock)

        // A deadline absurdly far out (a seconds-vs-millis epoch mixup) pins at
        // +Int.MAX instead of wrapping into a bogus small countdown…
        assertEquals(Int.MAX_VALUE, firstEmission(ticker.signedStream(Instant.DISTANT_FUTURE)))

        // …and a 0001-01-01-style null-sentinel deadline pins at -Int.MIN on the
        // signed stream — which the clamped stream then parks at 0.
        val sentinel = Instant.fromEpochMilliseconds(-62_135_596_800_000L) // 0001-01-01T00:00:00Z
        assertEquals(Int.MIN_VALUE, firstEmission(ticker.signedStream(sentinel)))
        assertEquals(ReachBy(0), firstEmission(ticker.stream(sentinel)))
    }
}
