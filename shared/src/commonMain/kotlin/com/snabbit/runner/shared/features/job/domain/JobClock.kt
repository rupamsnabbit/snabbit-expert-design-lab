package com.snabbit.runner.shared.features.job.domain

/**
 * Platform clock for the accept countdown. `commonMain` has no `kotlinx-datetime`,
 * so "now" and ISO-8601 → epoch parsing are provided per platform (Android
 * `java.time`, iOS `NSISO8601DateFormatter`). Injected into [JobViewModel] so
 * tests substitute a deterministic fake.
 */
interface JobClock {
    /** Current wall-clock time in epoch milliseconds. */
    fun nowMillis(): Long

    /** Epoch millis for an ISO-8601 timestamp (e.g. `2026-06-27T19:45:00+05:30`), or null if unparseable. */
    fun parseEpochMillis(iso: String): Long?

    /**
     * Epoch millis for **today** at [minutesOfDay] (0..1439) in the device's local zone —
     * anchors a wall-clock deadline to the current day. The check-in `check_in_time` can
     * carry a stale/nominal date, so its time-of-day is counted against today (matching the
     * label, which reads only the wall-clock). India-only app → local zone == runner's zone.
     */
    fun epochForLocalTimeToday(minutesOfDay: Int): Long
}

/** The production [JobClock] for the current platform. */
expect fun systemJobClock(): JobClock
