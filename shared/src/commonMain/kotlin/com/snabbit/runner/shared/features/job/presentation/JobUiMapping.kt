package com.snabbit.runner.shared.features.job.presentation

import com.snabbit.runner.shared.features.job.domain.JobClock
import com.snabbit.runner.shared.features.job.domain.JobTiming
import com.snabbit.runner.shared.features.job.domain.model.JobState

/**
 * Maps a raw domain [JobState] to its render state, applying the timing seeds (via [JobTiming])
 * and the string formatting the domain model deliberately omits. Pure + clock-injected → testable.
 * Action fields (submittingAction/error/success) stay at defaults here; JobViewModel.applyAction
 * overlays them.
 */
internal fun JobState.toUiState(clock: JobClock): JobUiState = when (this) {
    is JobState.New -> {
        val c = JobTiming.acceptCountdown(model, clock)
        JobUiState.NewJob(
            model = model,
            acceptRemainingSeconds = c.remainingSeconds,
            acceptTotalSeconds = c.totalSeconds,
        )
    }
    is JobState.AwaitingCheckIn -> {
        // Timer counts to start_time (Flutter check-in dial parity), NOT checkin_promise.
        val c = JobTiming.checkInCountdown(startTimeClock, payout?.checkInTimeIso, notifiedAtIso, clock)
        JobUiState.AwaitingCheckIn(
            jobId = jobId,
            allowNoOtp = allowNoOtp,
            customerName = customerName,
            customerPhone = customerPhone,
            address = address,
            geoAddress = geoAddress,
            latitude = latitude,
            longitude = longitude,
            payout = payout,
            notifiedAtIso = notifiedAtIso,
            checkInDeadlineIso = checkInDeadlineIso,
            isPastCheckIn = c?.isBonusForfeited ?: false,
            // null seed = no countdown; the footer gates its metric on this (never re-derives from raw fields).
            checkInRemainingSeconds = c?.remainingSeconds,
            checkInTotalSeconds = c?.totalSeconds ?: 0,
        )
    }
    is JobState.InProgress -> {
        val c = JobTiming.inProgressCountdown(endTimeIso, durationMinutes, clock)
        JobUiState.InProgress(
            jobId = jobId,
            customerName = customerName,
            customerPhone = customerPhone,
            jobTiming = formatJobTiming(startTimeIso, endTimeIso),
            durationLabel = durationMinutes?.let { "$it min" }.orEmpty(),
            preferences = preferences,
            nextJobReady = nextJobReady,
            showCheckoutOtp = showCheckoutOtp,
            cashToBeCollected = cashToBeCollected,
            campaignImageUrl = campaignImageUrl,
            checkoutBeforeMins = checkoutBeforeMins,
            autoCheckoutSeconds = autoCheckoutSeconds,
            endTimeIso = endTimeIso,
            durationMinutes = durationMinutes,
            remainingSeconds = c.remainingSeconds,
            totalSeconds = c.totalSeconds,
        )
    }
    is JobState.Completed -> JobUiState.Completed(
        jobId = jobId,
        customerId = customerId,
        customerName = customerName,
        customerAddress = customerAddress,
        payout = payout,
    )
}

/** `start_time` – `end_time` as a display range, e.g. "10:00 AM - 11:00 AM"; empty when both absent. */
private fun formatJobTiming(startIso: String?, endIso: String?): String {
    val start = formatIsoClockTime(startIso)
    val end = formatIsoClockTime(endIso)
    return when {
        start != null && end != null -> "$start - $end"
        else -> start ?: end.orEmpty()
    }
}
