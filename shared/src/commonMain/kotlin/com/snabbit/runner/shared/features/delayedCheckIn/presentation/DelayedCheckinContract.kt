package com.snabbit.runner.shared.features.job.delayedcheckin.presentation

import com.snabbit.runner.shared.features.job.delayedcheckin.domain.model.AwaitingCheckin
import com.snabbit.runner.shared.features.job.delayedcheckin.domain.model.SupportOption

/**
 * Render state for the delayed check-in penalty section on the v2 check-in
 * stage (LLD §"DelayedCheckinContract"). Owned by [DelayedCheckinViewModel];
 * [penalty] `null` means no penalty is active and the section renders
 * nothing (FR-02) — the stage falls back to its plain `CheckInFooter`.
 *
 * @property penalty the decoded `delayed_checkin_penalty` payload, or null.
 * @property remainingSeconds **signed** seconds to the penalty deadline —
 *   positive counting down, negative once overrun. The footer clamps its
 *   timer display at `00:00` (never a negative overrun); the sign lives on
 *   [isOverrun], which drives the full wash + the Help → "Call Partner
 *   Support" CTA swap. Ticks once a second while [penalty] is set.
 * @property supportSheet the "Call Support Partner" disposition sheet state.
 * @property submitting a disposition POST is in flight — the sheet's Submit
 *   spins and re-entry is blocked.
 */
data class DelayedCheckinUiState(
    val penalty: AwaitingCheckin? = null,
    val remainingSeconds: Int = 0,
    val supportSheet: SupportSheetState = SupportSheetState.Hidden,
    val submitting: Boolean = false,
) {
    /** Past the deadline — drives the footer's Help → "Call Partner Support" swap. */
    val isOverrun: Boolean get() = penalty != null && remainingSeconds < 0
}

/**
 * The disposition sheet's visibility. No `ConfigMissing` state (the LLD
 * sketch had one): missing/empty `job_support` config surfaces as an error
 * [DelayedCheckinEffect.Toast] instead of an opened sheet — the Dart parity
 * behaviour (`job_support_bottom_sheet.dart` shows a "Support details not
 * found" snackbar and never opens).
 */
sealed interface SupportSheetState {
    data object Hidden : SupportSheetState
    data class Shown(val options: List<SupportOption>) : SupportSheetState
}

/**
 * Every user action on the penalty section, as data. Sent to
 * [DelayedCheckinViewModel.onIntent] — single input channel. Reason
 * *selection* is deliberately absent: it's transient local input inside
 * `CallDispositionSheet` (the `CheckInSheet` OTP pattern); only the
 * submitted option reaches the ViewModel.
 */
sealed interface DelayedCheckinIntent {

    /**
     * Footer secondary CTA — open the disposition sheet (FR-11). Loads the
     * `job_support` options from the mirrored app config; in dial mode
     * (non-Ameyo) also starts the helpline prefetch so Submit can dial
     * without a second wait (FR-13).
     */
    data object SupportClicked : DelayedCheckinIntent

    /** Submit the chosen reason as the disposition (FR-12/13). */
    data class SubmitDisposition(val option: SupportOption) : DelayedCheckinIntent

    /** Scrim tap / back closed the disposition sheet. Ignored mid-submit. */
    data object DismissSheet : DelayedCheckinIntent
}

/**
 * One-shot effects the delayed check-in penalty flow asks the host to
 * perform (LLD §"DelayedCheckinContract"). Emitted by [DelayedCheckinViewModel]
 * and routed to the v2 job surfaces by
 * [DelayedCheckinEffectHandler] — the UI never fires platform intents
 * itself.
 */
sealed interface DelayedCheckinEffect {
    // NOTE: the LLD sketched an `OpenCheckIn` effect (FR-10, "app navigates").
    // On the v2 job screen the check-in sheet is screen-local, so the footer's
    // Check In CTA calls `CheckInUiIntent.Open` directly in `JobScreen` — an
    // effect round-trip would only add a droppable indirection.

    /** Open the platform dialler with [number] — dial-mode support (FR-13). */
    data class Dial(val number: String) : DelayedCheckinEffect

    /**
     * Transient feedback ("You will receive a call back soon" / error copy).
     * [success] picks the green vs red presentation once the penalty UI
     * lands; the v2 surface today is the job screen's snackbar.
     */
    data class Toast(val message: String, val success: Boolean) : DelayedCheckinEffect
}
