package com.snabbit.runner.shared.features.job.delayedcheckin.presentation

import com.snabbit.runner.shared.features.job.delayedcheckin.domain.model.ReachBy
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.map
import kotlin.time.Clock
import kotlin.time.Instant

private const val MILLIS_PER_SECOND = 1_000L

/**
 * Emits the remaining seconds to [deadline] once a (wall-clock-aligned)
 * second, as a [ReachBy]. [clock] is constructor-injected so tests can
 * fast-forward a fake clock instead of sleeping in real time.
 *
 * Each emission recomputes `deadline - clock.now()` from scratch — it never
 * accumulates a running total — so the countdown is correct immediately
 * after a process death, a backgrounded app catching up, or any other gap
 * between emissions. The `delay` at the end of the loop is sized to land on
 * the next wall-clock second boundary rather than a fixed 1000 ms after the
 * previous emission, so the ticker doesn't drift.
 *
 * **The flows never complete** — past the deadline [stream] keeps emitting
 * `ReachBy(0)` (and [signedStream] increasingly negative values) once a
 * second, forever. Deliberate, and it makes termination the collector's
 * job: the ViewModel must cancel collection (scope cancellation /
 * switching off the penalty state) when the countdown leaves the screen
 * or the penalty resolves.
 */
class ReachByTicker(private val clock: Clock = Clock.System) {

    fun stream(deadline: Instant): Flow<ReachBy> =
        signedStream(deadline).map { ReachBy(it.coerceAtLeast(0)) }

    /**
     * The signed sibling of [stream] for the "LATE BY" overrun display
     * (`DelayedCheckinFooter`): emits whole seconds to [deadline] —
     * positive counting down, `0` at the deadline, then increasingly
     * **negative** as the overrun grows (`-83` = 1 min 23 s late). Same
     * wall-clock-aligned cadence and recompute-from-scratch drift immunity.
     *
     * The Long→Int narrowing is **saturating** (clamped to the Int range
     * BEFORE `toInt()`): a garbage deadline decades away — a `0001-01-01`
     * null sentinel, a seconds-vs-milliseconds epoch mixup — pins at
     * ±Int.MAX instead of wrapping into a bogus small countdown.
     */
    fun signedStream(deadline: Instant): Flow<Int> = flow {
        while (true) {
            val now = clock.now()
            emit(
                (deadline - now).inWholeSeconds
                    .coerceIn(Int.MIN_VALUE.toLong(), Int.MAX_VALUE.toLong())
                    .toInt(),
            )
            delay(MILLIS_PER_SECOND - (now.toEpochMilliseconds() % MILLIS_PER_SECOND))
        }
    }
}
