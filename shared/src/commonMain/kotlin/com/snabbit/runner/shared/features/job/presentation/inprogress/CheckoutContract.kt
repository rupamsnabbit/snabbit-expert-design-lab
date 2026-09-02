package com.snabbit.runner.shared.features.job.presentation.inprogress

import com.snabbit.runner.shared.features.job.domain.model.JobMessage

/**
 * Render state for the checkout sub-flow — the **single** bottom sheet ([CheckoutSheet]) opened from
 * the in-progress "Complete Job" CTA, which morphs through [CheckoutStep]s in place (the same shape as
 * the check-in sheet): a post-job-end campaign nudge → the OTP entry that ends the job (`check_out`).
 * Owned by [CheckoutViewModel] (`uiState`, null = closed).
 *
 * Both steps are dismissible. The in-flight flag + wrong-OTP error live here so the sheet is
 * self-contained; the OTP text itself is transient local input. (The post-checkout house-tasks
 * selection is now a separate forced sheet on the Completed stage — ECPO-528.)
 *
 * @property step which sheet step is showing.
 * @property isSubmitting true while the `check_out` call is in flight (the End Job button spins).
 * @property errorMessage wrong-OTP / failure copy shown under the cells; null when none.
 */
data class CheckoutUiState(
    val step: CheckoutStep = CheckoutStep.Campaign,
    val isSubmitting: Boolean = false,
    val errorMessage: JobMessage? = null,
)

/** The steps the checkout sheet morphs through, in order (see [CheckoutUiState]). */
enum class CheckoutStep {
    /** Post-job-end campaign nudge; its progress CTA auto-advances to [Otp]. Dismissible. */
    Campaign,

    /** OTP entry to end the job (backend `check_out`). Dismissible. */
    Otp,
}

/**
 * Every user action on the checkout sheet, as data. The screen sends these to
 * [CheckoutViewModel.onIntent] — single input channel, so all transitions live in one exhaustive `when`.
 */
sealed interface CheckoutUiIntent {
    /**
     * Open the sheet (from the in-progress "Complete Job" CTA). Opens at the campaign step when
     * [hasCampaign], otherwise straight to OTP. The caller (JobScreen) passes `true` only on an EARLY
     * finish — more than the RC-controlled `expert_job_end_campaign_min_remaining_mins` (default 5 min)
     * of job time remaining at press; a normal end-of-job completion passes `false` (ECPO-860 #6).
     */
    data class Open(val hasCampaign: Boolean) : CheckoutUiIntent

    /** Campaign step's progress CTA completed (or was tapped) → advance to the OTP step. */
    data object CampaignComplete : CheckoutUiIntent

    /**
     * Submit the customer's [otp] to `check_out` (end the job). On 2xx the sheet stays up with the End Job
     * button still spinning (isSubmitting) and `current_state` refreshes; it closes only when the advance
     * to the Completed stage unmounts the sub-flow. A non-2xx surfaces an inline error and stays on the
     * OTP step.
     */
    data class EndJob(val otp: String) : CheckoutUiIntent

    /** Close the sheet (close button / scrim). */
    data object Dismiss : CheckoutUiIntent
}
