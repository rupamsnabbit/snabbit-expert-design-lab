package com.snabbit.runner.shared.features.job.presentation

/**
 * The top-level Job-screen actions (accept / deny / refresh + the Completed block flow), as data.
 * The screen sends these to [JobViewModel.onIntent] — a single input channel, so all transitions
 * live in one exhaustive `when` (child composables receive `onIntent`, never the VM).
 *
 * The stateful modal sub-flows (check-in, checkout) are their own MVI units with their own intent
 * types — [com.snabbit.runner.shared.features.job.presentation.checkin.CheckInUiIntent] /
 * [com.snabbit.runner.shared.features.job.presentation.inprogress.CheckoutUiIntent] — not this channel.
 */
sealed interface JobUiIntent {
    /** Accept the assigned job (`accept_job`), then refresh state. */
    data object Accept : JobUiIntent

    /** Deny the assigned job (`deny_job`), then refresh state. */
    data object Deny : JobUiIntent

    /**
     * Request that the in-app deny/logout warning sheet be opened for the current job (NOT a direct
     * deny). Fired by the draw-over-apps overlay's Deny: the overlay opens the app + tears itself down,
     * and the in-app New-Job screen opens the sheet from this shared request (ECPO-860 #3). The actual
     * `deny_job` still fires only from the sheet's CTA ([Deny]).
     */
    data object RequestDenyFlow : JobUiIntent

    /** The in-app deny sheet has been opened from a [RequestDenyFlow] — clear the pending request. */
    data object DenyFlowShown : JobUiIntent

    /** Ask the data source to re-fetch `current_state` now. */
    data object Refresh : JobUiIntent

    /** A transient action error has been shown — clear it. */
    data object ErrorShown : JobUiIntent

    /** A transient action success has been shown — clear it. */
    data object SuccessShown : JobUiIntent

    // ── Top-nav header actions (Figma 1:28063) ──

    /** SOS pill tapped. UI-only stub for now — the actual SOS trigger is host-wired. */
    data object TapSos : JobUiIntent

    /** Help pill tapped. UI-only stub for now — the destination (help centre) is host-wired. */
    data object TapHelp : JobUiIntent

    /** System back pressed while a job is active (the host consumes it; this records the tap). */
    data object BackPressed : JobUiIntent

    // The check-in sub-flow (CheckInSheet: OTP → phone → success) is its own MVI unit — see
    // CheckInViewModel / CheckInUiIntent — so its actions are not on this channel.

    // The deny/logout warning sheet (JobDenyFlowSheet) is a stateless sheet — its open/closed state
    // is composable-local (the screen), and it reads isLastHour/lossAmount off the NewJob model. Its
    // Deny (or, for a last-hour job, "Logout") CTA fires [Deny] — the backend treats a last-hour deny
    // as the shift logout, and the refreshed state returns the attendance widget, which the legacy
    // Flutter surface renders. Marking attendance is not part of this flow.

    // The in-progress checkout sub-flow (campaign → OTP → tasks-done) is its own MVI unit — see
    // CheckoutViewModel / CheckoutUiIntent — so its actions are not on this channel.

    // ── Completed → block-customer sub-flow (BlockCustomerSheet) ──

    /** Open the block-customer confirmation sheet (from the Completed block card's "Block"). */
    data object OpenBlockFlow : JobUiIntent

    /** Close the block-customer sheet (No / scrim / close), before a block succeeds. */
    data object DismissBlockFlow : JobUiIntent

    /**
     * A block succeeded (fired from the sheet's `blocked` one-shot) — flip the card to its Unblock
     * state, show the "customer blocked" toast, and close the sheet (the screen stays on Completed).
     */
    data object CustomerBlocked : JobUiIntent

    /** Unblock the just-blocked customer (from the card's "Unblock"), reverting the card. */
    data object UnblockCustomer : JobUiIntent

    /**
     * Dismiss the forced post-checkout house-tasks sheet for [jobId] — allowed only once its
     * `task_collection` fetch has errored (the sheet becomes dismissible then) so the runner isn't
     * trapped behind the scrim. Closes the show-once gate in memory (not persisted → a relaunch retries).
     */
    data class DismissHouseTasks(val jobId: Int) : JobUiIntent
}
