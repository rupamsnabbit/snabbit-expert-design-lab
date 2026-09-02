package com.snabbit.runner.shared.features.job

import com.snabbit.runner.shared.features.job.domain.JobClock

/**
 * Deterministic [JobClock] for tests: fixed [now]; [parsed] maps ISO strings to epoch
 * millis; [startOfDay] is local midnight so `epochForLocalTimeToday(m)` == startOfDay + m·60s.
 */
class FakeJobClock(
    private val now: Long = 0L,
    private val parsed: Map<String, Long?> = emptyMap(),
    private val startOfDay: Long = 0L,
) : JobClock {
    override fun nowMillis(): Long = now
    override fun parseEpochMillis(iso: String): Long? = parsed[iso]
    override fun epochForLocalTimeToday(minutesOfDay: Int): Long = startOfDay + minutesOfDay * 60_000L
}
