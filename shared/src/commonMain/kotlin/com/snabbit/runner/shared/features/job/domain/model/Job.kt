package com.snabbit.runner.shared.features.job.domain.model

/**
 * Raw, presentation-free slice of a job lifecycle stage, projected from the
 * `current_state` envelope by JobProjector. Holds ONLY envelope data — no formatted
 * strings, no timing seeds, no action state. Those are derived in Job.toUiState(...).
 */
sealed interface JobState {
    val jobId: Int?

    /** `RUNNER_NEW_JOB`. Wraps the existing NewJobModel (already raw). */
    data class New(val model: NewJobModel) : JobState {
        override val jobId: Int? get() = model.jobId
    }

    /** `RUNNER_JOB_POST_ACCEPT` / `RUNNER_JOB_CHECK_IN`. */
    data class AwaitingCheckIn(
        override val jobId: Int?,
        val allowNoOtp: Boolean = false,
        val customerName: String? = null,
        val customerPhone: String? = null,
        val address: String? = null,
        /** `geo_address` — the secondary address line (landmark/area); shown under [address]. */
        val geoAddress: String? = null,
        val latitude: Double? = null,
        val longitude: Double? = null,
        val payout: JobPayout? = null,
        val notifiedAtIso: String? = null,
        /** `start_time` — the job's scheduled start (a 12-hour wall-clock string); drives the check-in timer. */
        val startTimeClock: String? = null,
        val checkInDeadlineIso: String? = null,
    ) : JobState

    /** `RUNNER_JOB_IN_PROGRESS`. Raw ISO times + minutes; formatting happens at map time. */
    data class InProgress(
        override val jobId: Int?,
        val customerName: String? = null,
        val customerPhone: String? = null,
        val startTimeIso: String? = null,
        val endTimeIso: String? = null,
        val durationMinutes: Int? = null,
        val preferences: List<JobPreference> = emptyList(),
        val nextJobReady: Boolean = false,
        val showCheckoutOtp: Boolean = false,
        val cashToBeCollected: Boolean = false,
        val campaignImageUrl: String? = null,
        val checkoutBeforeMins: Int = DEFAULT_CHECKOUT_BEFORE_MINS,
        val autoCheckoutSeconds: Int? = null,
    ) : JobState

    /** `RUNNER_POST_CHECKOUT`. */
    data class Completed(
        override val jobId: Int?,
        val customerId: Int? = null,
        val customerName: String? = null,
        val customerAddress: String? = null,
        val payout: JobPayout? = null,
    ) : JobState
}

/**
 * A neutral customer/cooking-preference row (icon resolved at render time from [key]).
 * Moved from presentation so domain JobState.InProgress can hold it (domain imports no presentation).
 */
data class JobPreference(
    val key: String,
    val label: String,
    val value: String,
)
