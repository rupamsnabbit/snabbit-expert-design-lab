package com.snabbit.runner.shared.features.job.presentation.checkin

import com.snabbit.runner.shared.features.job.domain.model.JobMessage

/**
 * Render state for the check-in sub-flow — a **single** bottom sheet ([CheckInSheet]) that morphs
 * through [CheckInStep]s in place (OTP → phone fallback → success), rather than opening a separate
 * sheet per step. Owned by [CheckInViewModel] (`uiState`, null = closed).
 *
 * Self-contained: the in-flight flag + OTP/phone error copy live here (not on the shared
 * `JobActionStore`, which now serves only accept/deny). Decoupled from the polled envelope: on a
 * successful check-in the stage advance (the `requestRefresh` that flips `current_state` to
 * `IN_PROGRESS`) is **deferred** to [CheckInUiIntent.SuccessAcknowledged], so the sheet can show the
 * [CheckInStep.Success] celebration first.
 *
 * @property step the current sheet step.
 * @property isSubmitting a `start_job` call is in flight — the Start Job button shows loading.
 * @property errorMessage wrong-OTP / phone-mismatch copy, shown inline under the cells; null when none.
 */
data class CheckInUiState(
    val step: CheckInStep = CheckInStep.Otp,
    val isSubmitting: Boolean = false,
    val errorMessage: JobMessage? = null,
)

/** The steps the single check-in sheet morphs through. */
enum class CheckInStep {
    /** Enter the customer's OTP (`start_job`); offers the no-OTP fallback when the job allows it. */
    Otp,

    /** No-OTP fallback: enter the customer's booking phone number instead. */
    Phone,

    /**
     * Terminal celebration ("Job Started") with an auto-advancing progress button. On its
     * completion the flow closes and the stage advances. Forced — no scrim/back/close escape.
     */
    Success,
}

/**
 * Every user action on the check-in sheet, as data. The screen sends these to
 * [CheckInViewModel.onIntent] — single input channel, so all transitions live in one exhaustive `when`.
 */
sealed interface CheckInUiIntent {
    /** Open the sheet at the OTP step (from the footer "Check In" CTA). */
    data object Open : CheckInUiIntent

    /**
     * Submit the customer's [otp] to `start_job` (OTP check-in). On 2xx the sheet advances to its
     * [CheckInStep.Success] step (the stage advance is deferred to [SuccessAcknowledged]); a non-2xx
     * surfaces an inline "incorrect OTP" error.
     */
    data class StartJob(val otp: String) : CheckInUiIntent

    /**
     * Submit the customer's [phone] for no-OTP check-in (`start_job` with the booking phone number).
     * Same success path as [StartJob]; a non-2xx surfaces an inline "phone doesn't match" error.
     */
    data class CheckInWithPhone(val phone: String) : CheckInUiIntent

    /** OTP step → phone-number fallback ("No OTP"). Clears any prior inline error. */
    data object SwitchToPhone : CheckInUiIntent

    /** Phone step → OTP ("Use OTP instead"). Clears any prior inline error. */
    data object SwitchToOtp : CheckInUiIntent

    /** Close the sheet (close button / scrim / back), OTP & phone steps only. */
    data object Dismiss : CheckInUiIntent

    /**
     * The success step's progress animation completed (or the runner tapped it) — advance the stage
     * (`requestRefresh` → `IN_PROGRESS`) and close the sheet. Idempotent: a no-op if the flow is
     * already closed (e.g. a background poll already advanced the stage).
     */
    data object SuccessAcknowledged : CheckInUiIntent
}
