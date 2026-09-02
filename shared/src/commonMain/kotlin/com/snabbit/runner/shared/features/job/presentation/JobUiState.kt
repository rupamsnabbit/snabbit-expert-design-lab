package com.snabbit.runner.shared.features.job.presentation

import com.snabbit.runner.shared.features.job.data.JobSubmitAction
import com.snabbit.runner.shared.features.job.domain.model.DEFAULT_CHECKOUT_BEFORE_MINS
import com.snabbit.runner.shared.features.job.domain.model.JobMessage
import com.snabbit.runner.shared.features.job.domain.model.JobPayout
import com.snabbit.runner.shared.features.job.domain.model.JobPreference
import com.snabbit.runner.shared.features.job.domain.model.NewJobModel

/**
 * Render state for the top-level Job screen — one host whose body swaps with the
 * runner's job lifecycle stage (the KMP analogue of `partner_home.dart` +
 * `widgets_util.dart`, scoped to the job flow).
 *
 * Projected from the `current_state` envelope to a raw domain `Job` by `toJob`, then
 * mapped here by `Job.toUiState`; the [NewJob] accept-countdown and the [AwaitingCheckIn]
 * / [InProgress] deadlines are seeded once per envelope via `JobTiming` (using [JobClock]),
 * and the in-flight accept/deny action is overlaid in [JobViewModel].
 */
sealed interface JobUiState {
    /** Nothing pushed yet (cold mount before the first state arrives). */
    data object Loading : JobUiState

    /** Current state isn't a job lifecycle stage — host falls back to legacy UI. */
    data object NotInJobFlow : JobUiState

    /** `RUNNER_NEW_JOB` — the assignment to accept/deny. */
    data class NewJob(
        val model: NewJobModel,
        /** Seconds left on the accept countdown at envelope time; the screen ticks down from here. */
        val acceptRemainingSeconds: Int = 0,
        /** Full accept window in seconds (`timer_duration`); drives the progress fill. */
        val acceptTotalSeconds: Int = 0,
        /**
         * Which accept/deny call is in flight (null = idle). The footer spins the matching button and
         * disables the other, so a deny no longer shows the loading spinner on Accept.
         */
        val submittingAction: JobSubmitAction? = null,
        /** Transient action-failure message (non-2xx) — shown as a red toast, then cleared. */
        val errorMessage: JobMessage? = null,
        /** Transient action-success message (2xx) — shown as a success toast, then cleared. */
        val successMessage: JobMessage? = null,
    ) : JobUiState {
        /** Any accept/deny call in flight — the double-submit guard / "both buttons disabled" signal. */
        val isSubmitting: Boolean get() = submittingAction != null
    }

    /**
     * `RUNNER_JOB_POST_ACCEPT` / `RUNNER_JOB_CHECK_IN` — the runner has reached the job
     * location: the check-in screen (job-state header + earnings card + navigation card),
     * with a "Check In" footer CTA that opens the OTP sheet.
     *
     * Screen data ([customerName], [address], [payout]) is mapped from the envelope. Two distinct
     * timing concerns, deliberately decoupled: the footer **countdown** seed
     * ([checkInRemainingSeconds] / [checkInTotalSeconds]) is driven by the job's `start_time`
     * (matching the Flutter check-in dial), while [isPastCheckIn] tracks the separate **bonus
     * deadline** ([JobPayout.checkInTimeIso]) passing — which strikes the earnings card and drives
     * the forfeit instrumentation. Both seeds are computed once per envelope by [JobViewModel] via
     * [com.snabbit.runner.shared.features.job.domain.JobClock]; the footer ticks locally from the seed
     * (like the accept countdown).
     *
     * This state is pure envelope data — the check-in sheet's in-flight flag / inline error live on
     * its own `CheckInViewModel`, and the OTP text is transient local sheet input.
     */
    data class AwaitingCheckIn(
        val jobId: Int?,
        /** `allow_check_in_without_otp` — gates the in-sheet "No OTP" fallback button. */
        val allowNoOtp: Boolean = false,
        /** `customer_name` — navigation card header (falls back to a generic label). */
        val customerName: String? = null,
        /** `customer_ph_no` — the customer's number, for the nav-card Call action (masked call). */
        val customerPhone: String? = null,
        /** `address` — navigation card address line. */
        val address: String? = null,
        /** `geo_address` — the secondary address line; shown under [address] so the full address renders. */
        val geoAddress: String? = null,
        /** `lat` / `lng` — customer location, for the nav-card Map (walking navigation) action. */
        val latitude: Double? = null,
        val longitude: Double? = null,
        /** `payout_info` — earnings breakdown + check-in bonus (amount + deadline). */
        val payout: JobPayout? = null,
        /** `notified_at` — start of the check-in window, for the footer's progress fill. */
        val notifiedAtIso: String? = null,
        /**
         * `checkin_promise` — the absolute check-in deadline. Used only for the `CHECK IN BY …`
         * label fallback (the label prefers [JobPayout.checkInTimeIso], the bonus deadline). The
         * footer **countdown** is driven by `start_time` (see [AwaitingCheckIn] timing seed below),
         * matching the Flutter check-in dial — not this field.
         */
        val checkInDeadlineIso: String? = null,
        /** The check-in **bonus** deadline (`check_in_time`) has passed: reduced/struck earnings + forfeit logged. */
        val isPastCheckIn: Boolean = false,
        /**
         * Seconds to the `start_time` countdown at envelope time (negative once past); footer ticks from
         * here. **`null` means no countdown exists** (no parseable `start_time`/bonus) — the footer gates
         * the whole metric on this, so the gate and the value can never disagree.
         */
        val checkInRemainingSeconds: Int? = null,
        /** The countdown window in seconds (`start_time - notified_at`), driving the progress fill; 0 = unknown. */
        val checkInTotalSeconds: Int = 0,
    ) : JobUiState

    /**
     * `RUNNER_JOB_IN_PROGRESS` — the job is running until the runner completes it. Screen data
     * ([customerName], [jobTiming], [durationLabel], [preferences]) is mapped from the envelope; the
     * **remaining-time countdown** ([remainingSeconds] / [totalSeconds]) is seeded once per envelope
     * by [JobViewModel] from [endTimeIso] + [durationMinutes] (via
     * [com.snabbit.runner.shared.features.job.domain.JobClock]) and the screen ticks it locally — driving the
     * pill colour (green → yellow → red), the gradient, the status callout, and when **Complete Job**
     * enables. Mirrors `on_the_job.dart`'s `timerPeriodicProcess` thresholds: remaining ≤
     * [checkoutBeforeMins]·60 = yellow; the last minute / the [autoCheckoutSeconds] window = red.
     *
     * The checkout routing hints ([showCheckoutOtp] / [cashToBeCollected]) are carried for the
     * checkout flow; Complete Job opens the checkout sheet (its own `CheckoutViewModel`).
     */
    data class InProgress(
        val jobId: Int?,
        /** `customer_name` — job-details card header (falls back to a generic label). */
        val customerName: String? = null,
        /** `customer_ph_no` — the number for the card's Call action (masked call). */
        val customerPhone: String? = null,
        /** Pre-formatted `start_time` – `end_time` range, e.g. "10:00 AM - 11:00 AM". */
        val jobTiming: String = "",
        /** Pre-formatted base `duration`, e.g. "60 min". */
        val durationLabel: String = "",
        /** Pre-formatted extension, e.g. "+15 min"; null when not extended (deferred — see plan). */
        val extraDurationLabel: String? = null,
        /** `cooking_preference` entries (spice/oil level, …) for the preferences card. */
        val preferences: List<JobPreference> = emptyList(),
        /** `next_job_ready` — surfaces the "next job ready, check out" status callout. */
        val nextJobReady: Boolean = false,
        /** `show_checkout_otp` — checkout routing hint (checkout flow wired later). */
        val showCheckoutOtp: Boolean = false,
        /** `cash_to_be_collected` — checkout routing hint (checkout flow wired later). */
        val cashToBeCollected: Boolean = false,
        /**
         * Post-job-end campaign illustration shown as the first step of the checkout sheet (the
         * [com.snabbit.runner.shared.features.job.presentation.inprogress.PostJobEndCampaign] nudge). Null → no
         * campaign, so the checkout flow opens straight at the OTP step.
         */
        val campaignImageUrl: String? = null,
        /** `checkout_before_mins` — remaining ≤ this·60 flips the pill/gradient to yellow (default 5). */
        val checkoutBeforeMins: Int = DEFAULT_CHECKOUT_BEFORE_MINS,
        /** `auto_checkout_seconds` — post-end auto-checkout window (drives the red "auto checkout" callout). */
        val autoCheckoutSeconds: Int? = null,
        /** `end_time` ISO — seeds [remainingSeconds] via `JobTiming` in `Job.toUiState`. */
        val endTimeIso: String? = null,
        /** `duration` in minutes — seeds [totalSeconds] (the pill's progress denominator). */
        val durationMinutes: Int? = null,
        /** Seconds to `end_time` at envelope time (negative once over); the screen ticks from here. */
        val remainingSeconds: Int = 0,
        /** The full job window in seconds (`duration`·60), driving the pill fill; 0 = unknown. */
        val totalSeconds: Int = 0,
    ) : JobUiState

    /**
     * `RUNNER_POST_CHECKOUT` — the job is done: the completion screen shows the earnings, a
     * rate-the-customer card, and (once the runner rates 1★) a block-customer option, over a
     * "Ready for next job" CTA. Screen data ([payout], [customerName], [customerId], [customerAddress])
     * is mapped from the envelope; the rating lives in a reused [com.snabbit.runner.shared.features.job.presentation.completed.rating.CustomerRatingViewModel]
     * (created via [JobViewModel.createRatingViewModel]) and the block flow in a reused
     * [com.snabbit.runner.shared.features.blocklist.presentation.blockcustomer.BlockCustomerViewModel] (opened via [JobUiIntent.OpenBlockFlow]).
     */
    data class Completed(
        val jobId: Int?,
        /** `customer_id` — passed to the block / unblock API. */
        val customerId: Int? = null,
        /** `customer_name` — block card header + confirmation sheet. */
        val customerName: String? = null,
        /** `address` — the block sheet's max-reached "unblock to block" header. */
        val customerAddress: String? = null,
        /** `payout_info` — the earnings accordion ("You Earned"). */
        val payout: JobPayout? = null,
    ) : JobUiState
}
