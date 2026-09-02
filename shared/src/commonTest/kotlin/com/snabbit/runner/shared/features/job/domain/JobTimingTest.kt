package com.snabbit.runner.shared.features.job.domain

import com.snabbit.runner.shared.features.job.FakeJobClock
import com.snabbit.runner.shared.features.job.domain.model.JobCategory
import com.snabbit.runner.shared.features.job.domain.model.NewJobModel
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

private fun newJob(timer: Int, notifiedAtIso: String?) = NewJobModel(
    jobId = 1, isDeniable = true, isLastHourJob = false, showDeallocationWarning = false,
    notifiedAtIso = notifiedAtIso, timerDurationSec = timer, denyRate = null, lossAmount = null,
    address = null, geoAddress = null, isLongDistance = false,
    category = JobCategory.Expert, payout = null,
)

class JobTimingTest {

    @Test
    fun accept_countdown_from_notified_at_plus_timer() {
        // notified 30s ago, 120s window -> 90s remaining, 120 total
        val clock = FakeJobClock(now = 1_000_000L, parsed = mapOf("N" to 970_000L))
        val c = JobTiming.acceptCountdown(newJob(timer = 120, notifiedAtIso = "N"), clock)
        assertEquals(90, c.remainingSeconds)
        assertEquals(120, c.totalSeconds)
    }

    @Test
    fun accept_countdown_clamps_to_zero_when_past() {
        val clock = FakeJobClock(now = 1_000_000L, parsed = mapOf("OLD" to 1_000L))
        val c = JobTiming.acceptCountdown(newJob(timer = 120, notifiedAtIso = "OLD"), clock)
        assertEquals(0, c.remainingSeconds)
        assertEquals(120, c.totalSeconds)
    }

    @Test
    fun accept_countdown_defaults_start_to_now_when_notified_absent() {
        val clock = FakeJobClock(now = 1_000_000L)
        val c = JobTiming.acceptCountdown(newJob(timer = 60, notifiedAtIso = null), clock)
        assertEquals(60, c.remainingSeconds)
        assertEquals(60, c.totalSeconds)
    }

    @Test
    fun checkin_countdown_null_when_no_deadline() {
        val clock = FakeJobClock(now = 1_000_000L)
        assertNull(JobTiming.checkInCountdown(null, null, null, clock))
    }

    @Test
    fun checkin_countdown_remaining_negative_when_start_time_elapsed() {
        // start_time 10:00 am (600 min); startOfDay 0 -> anchored epoch 36_000_000; now 36_400_000 -> -400s, past.
        val clock = FakeJobClock(now = 36_400_000L, startOfDay = 0L)
        val c = JobTiming.checkInCountdown("10:00 am", null, null, clock)!!
        assertEquals(-400, c.remainingSeconds)
        assertEquals(0, c.totalSeconds) // no notified_at start -> unknown window
        assertFalse(c.isBonusForfeited) // no bonus deadline -> nothing to forfeit
    }

    @Test
    fun checkin_countdown_window_from_notified_to_deadline() {
        // notified 09:00 (540), start_time 10:00 am (600) -> 3600s window
        val clock = FakeJobClock(now = 0L, startOfDay = 0L)
        val c = JobTiming.checkInCountdown(
            startTimeClock = "10:00 am",
            checkInBonusIso = null,
            notifiedAtIso = "2026-07-09T09:00:00+05:30",
            clock = clock,
        )!!
        assertEquals(3600, c.totalSeconds)
    }

    @Test
    fun checkin_countdown_falls_back_to_bonus_iso() {
        // no checkin_promise; bonus deadline 08:00 (480) -> epoch 28_800_000; now 0 -> remaining 28800
        val clock = FakeJobClock(now = 0L, startOfDay = 0L)
        val c = JobTiming.checkInCountdown(null, "2026-07-09T08:00:00+05:30", null, clock)!!
        assertEquals(28_800, c.remainingSeconds)
    }

    @Test
    fun checkin_countdown_convertsUtcTimeToIst_anchoredToday() {
        // The bonus-ISO fallback is converted to its IST TIME-OF-DAY and anchored to TODAY; its nominal
        // far date is ignored. 20:57Z == 02:27 IST -> 147 min -> epochForLocalTimeToday(147) = 8_820_000;
        // now 8_220_000 -> 600s remaining, NOT the ~years the 2030 date would give (ECPO-860 TZ fix, not
        // off by 5½h). Passed as the bonus arg since start_time (the primary) is a bare clock string.
        val clock = FakeJobClock(now = 8_220_000L, startOfDay = 0L)
        val c = JobTiming.checkInCountdown(null, "2030-01-15T20:57:00Z", null, clock)!!
        assertEquals(600, c.remainingSeconds)
        assertFalse(c.isBonusForfeited)
    }

    @Test
    fun checkin_countdown_parses_start_time_clock_string() {
        // start_time "7:30 pm" -> 19:30 IST -> 1170 min -> epochForLocalTimeToday(1170) = 70_200_000; now 0
        // -> 70_200s remaining. Proves the 12-hour wall-clock format (job_accepted.dart) drives the timer.
        val clock = FakeJobClock(now = 0L, startOfDay = 0L)
        val c = JobTiming.checkInCountdown("7:30 pm", null, null, clock)!!
        assertEquals(70_200, c.remainingSeconds)
        assertFalse(c.isBonusForfeited)
    }

    @Test
    fun checkin_countdown_prefers_start_time_over_bonus() {
        // start_time 10:00 am (600 -> 36_000_000) wins over the bonus 08:00 (480); now 0 -> 36_000s.
        val clock = FakeJobClock(now = 0L, startOfDay = 0L)
        val c = JobTiming.checkInCountdown("10:00 am", "2026-07-09T08:00:00+05:30", null, clock)!!
        assertEquals(36_000, c.remainingSeconds)
    }

    @Test
    fun checkin_countdown_bonus_not_forfeited_when_only_start_time_passed() {
        // Comment-2 case: last-hour job whose start_time (08:00, 28_800_000) already passed at accept,
        // but the bonus check_in_time (10:00, 36_000_000) is still minutes out. now 30_000_000:
        // countdown is late (-1200s) yet the bonus is NOT forfeited — the two must not move together.
        val clock = FakeJobClock(now = 30_000_000L, startOfDay = 0L)
        val c = JobTiming.checkInCountdown("08:00 am", "2026-07-09T10:00:00+05:30", null, clock)!!
        assertEquals(-1200, c.remainingSeconds) // start_time countdown already past
        assertFalse(c.isBonusForfeited) // bonus window still open
    }

    @Test
    fun checkin_countdown_bonus_forfeited_tracks_bonus_deadline_not_start_time() {
        // Inverse: start_time (12:00 pm, 43_200_000) still ahead, but the bonus check_in_time (08:00,
        // 28_800_000) has passed. now 30_000_000: countdown positive yet the bonus IS forfeited.
        val clock = FakeJobClock(now = 30_000_000L, startOfDay = 0L)
        val c = JobTiming.checkInCountdown("12:00 pm", "2026-07-09T08:00:00+05:30", null, clock)!!
        assertEquals(13_200, c.remainingSeconds) // start_time countdown not yet late
        assertTrue(c.isBonusForfeited) // bonus deadline already elapsed
    }

    @Test
    fun clockTimeIstMinutes_parses_all_wall_clock_forms() {
        // The exact backend forms (leading-zero hour + space before meridiem), plus the 12-o'clock edges.
        assertEquals(18 * 60 + 30, clockTimeIstMinutes("06:30 pm")) // leading-zero PM -> 18:30 = 1110
        assertEquals(4 * 60 + 2, clockTimeIstMinutes("04:02 am")) // leading-zero AM -> 04:02 = 242
        assertEquals(0, clockTimeIstMinutes("12:00 am")) // midnight -> 00:00
        assertEquals(12 * 60, clockTimeIstMinutes("12:00 pm")) // noon -> 12:00
        assertEquals(9 * 60 + 5, clockTimeIstMinutes("9:05 AM")) // single-digit hour, uppercase meridiem
        // Non-wall-clock inputs return null so the caller falls through to the ISO parser.
        assertNull(clockTimeIstMinutes("2026-07-09T10:00:00+05:30"))
        assertNull(clockTimeIstMinutes("10:00")) // no meridiem
        assertNull(clockTimeIstMinutes(null))
    }

    @Test
    fun inprogress_countdown_from_end_time_and_duration() {
        // end 60s ahead, duration 60 min -> remaining 60, total 3600
        val clock = FakeJobClock(now = 1_000_000L, parsed = mapOf("END" to 1_060_000L))
        val c = JobTiming.inProgressCountdown(endTimeIso = "END", durationMinutes = 60, clock = clock)
        assertEquals(60, c.remainingSeconds)
        assertEquals(3600, c.totalSeconds)
    }

    @Test
    fun inprogress_countdown_defaults_when_absent() {
        val clock = FakeJobClock(now = 1_000_000L)
        val c = JobTiming.inProgressCountdown(endTimeIso = null, durationMinutes = null, clock = clock)
        assertEquals(0, c.remainingSeconds)
        assertEquals(0, c.totalSeconds)
    }
}
