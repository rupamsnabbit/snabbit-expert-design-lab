package com.snabbit.runner.shared.features.job.presentation

import com.snabbit.runner.shared.features.job.FakeJobClock
import com.snabbit.runner.shared.features.job.domain.model.JobState
import com.snabbit.runner.shared.features.job.domain.model.JobCategory
import com.snabbit.runner.shared.features.job.domain.model.NewJobModel
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs

class JobUiMappingTest {

    @Test
    fun inprogress_job_maps_to_uistate_with_formatting_and_timing() {
        val endIso = "2026-07-09T11:00:00+05:30"
        val clock = FakeJobClock(now = 1_000_000L, parsed = mapOf(endIso to 1_060_000L))
        val job = JobState.InProgress(
            jobId = 42, customerName = "Asha",
            startTimeIso = "2026-07-09T10:00:00+05:30",
            endTimeIso = endIso, durationMinutes = 60,
        )

        val ui = job.toUiState(clock)

        assertIs<JobUiState.InProgress>(ui)
        assertEquals("10:00 AM - 11:00 AM", ui.jobTiming) // formatted from raw start/end
        assertEquals("60 min", ui.durationLabel)
        assertEquals(60, ui.remainingSeconds) // (1_060_000 - 1_000_000)/1000
        assertEquals(3600, ui.totalSeconds) // 60 min * 60
        assertEquals(endIso, ui.endTimeIso) // raw seed preserved for local ticking
    }

    @Test
    fun awaiting_checkin_maps_start_time_countdown_without_bonus_forfeit() {
        // start_time 10:00 am (600 min); startOfDay 0 -> anchored epoch 36_000_000; now 36_400_000 -> -400s.
        // No bonus deadline in this envelope, so the countdown is past but isPastCheckIn stays false.
        val clock = FakeJobClock(now = 36_400_000L, startOfDay = 0L)
        val job = JobState.AwaitingCheckIn(
            jobId = 7, customerName = "Ravi",
            startTimeClock = "10:00 am",
        )

        val ui = job.toUiState(clock)

        assertIs<JobUiState.AwaitingCheckIn>(ui)
        assertEquals(false, ui.isPastCheckIn) // bonus-forfeit is decoupled from the start_time countdown
        assertEquals(-400, ui.checkInRemainingSeconds)
        assertEquals("Ravi", ui.customerName)
    }

    @Test
    fun new_job_maps_accept_countdown() {
        val clock = FakeJobClock(now = 1_000_000L) // notified null -> start == now
        val job = JobState.New(
            NewJobModel(
                jobId = 1, isDeniable = true, isLastHourJob = false, showDeallocationWarning = false,
                notifiedAtIso = null, timerDurationSec = 90, denyRate = null, lossAmount = null,
                address = null, geoAddress = null, isLongDistance = false,
                category = JobCategory.Expert, payout = null,
            ),
        )

        val ui = job.toUiState(clock)

        assertIs<JobUiState.NewJob>(ui)
        assertEquals(90, ui.acceptRemainingSeconds)
        assertEquals(90, ui.acceptTotalSeconds)
    }

    @Test
    fun completed_maps_directly() {
        val clock = FakeJobClock(now = 0L)
        val job = JobState.Completed(jobId = 7, customerId = 42, customerName = "Meera")

        val ui = job.toUiState(clock)

        assertIs<JobUiState.Completed>(ui)
        assertEquals(7, ui.jobId)
        assertEquals(42, ui.customerId)
        assertEquals("Meera", ui.customerName)
    }
}
