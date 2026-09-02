package com.snabbit.runner.shared.features.shift.presentation.emergencylogout

import com.snabbit.runner.shared.features.periodleave.domain.model.PeriodLeaveAvailability
import com.snabbit.runner.shared.features.shift.core.domain.model.EmergencyLogoutAvailability

/**
 * Render state for the emergency-logout sheet.
 *
 * Two independent fetches feed this state — emergency-logout availability and
 * period-leave availability. They run in parallel on [EmergencyLogoutUiIntent.Load];
 * we only flip `isLoading` off once BOTH settle. A period-leave failure does
 * not block the sheet — the row simply hides ([showPeriodLeaveRow] is false
 * when `periodLeave == null`); the emergency-logout failure does block (no
 * availability means we can't render the sheet body responsibly).
 *
 * Successful logout sets [finished] (or [showTakeCare] first if the runner
 * used period leave) — the screen consumes those to dismiss / transition.
 */
data class EmergencyLogoutUiState(
    val isLoading: Boolean = true,
    val isSubmitting: Boolean = false,
    val availability: EmergencyLogoutAvailability? = null,
    val periodLeave: PeriodLeaveAvailability? = null,
    val periodLeaveChecked: Boolean = false,
    /** Which failure occurred, if any — the screen resolves it to copy via
     *  [EmergencyLogoutStrings.messageFor]. Kept as a type, not a string, so the
     *  VM never touches user-facing copy. */
    val errorType: EmergencyLogoutError? = null,
    /** True after a period-leave logout succeeds and we should show TakeCare. */
    val showTakeCare: Boolean = false,
    /** True after the flow is fully done; the screen emits Finish on observe. */
    val finished: Boolean = false,
) {
    /** Show the period-leave row only when entitlement is loaded AND positive. */
    val showPeriodLeaveRow: Boolean
        get() = periodLeave?.let { it.available && it.remaining > 0 } == true

    /** Effective `period_leave` flag posted to the BE — false when the row is hidden. */
    val effectivePeriodLeave: Boolean
        get() = showPeriodLeaveRow && periodLeaveChecked

    /** Logout CTA is actionable only after availability is loaded, with logouts remaining, and nothing in flight. */
    val canConfirm: Boolean
        get() = !isLoading && !isSubmitting && availability?.available == true
}

/**
 * Every user action on the emergency-logout sheet, as data. The screen sends
 * these to [EmergencyLogoutViewModel.onIntent] — single input channel, so all
 * state transitions live in one exhaustive `when`.
 */
/** The two failure modes the sheet surfaces — resolved to copy in the UI. */
enum class EmergencyLogoutError { Load, Confirm }

sealed interface EmergencyLogoutUiIntent {
    /** Initial load + retry — fans out to both availability fetches in parallel. */
    data object Load : EmergencyLogoutUiIntent

    /** Period-leave row checkbox toggled. */
    data class TogglePeriodLeave(val checked: Boolean) : EmergencyLogoutUiIntent

    /** "Logout" CTA tapped — fires the POST. */
    data object Confirm : EmergencyLogoutUiIntent

    /** "Go back" CTA / scrim tap / back press — close the sheet. */
    data object Dismiss : EmergencyLogoutUiIntent

    /** TakeCare sheet's CTA tapped — finish the flow. */
    data object AcknowledgeTakeCare : EmergencyLogoutUiIntent

    /** Transient (confirm-failure) error has been shown — clear it. */
    data object ErrorShown : EmergencyLogoutUiIntent
}

/**
 * One-shot side effects from [EmergencyLogoutViewModel]. Surfaced via
 * `effects: SharedFlow` so a re-subscription doesn't replay them. Matches
 * the [ShiftLoginUiEffect] convention.
 */
sealed interface EmergencyLogoutUiEffect {
    /**
     * Flow is done — host should dismiss the screen and refresh runner state
     * so Dart picks up the post-logout `current_state` envelope.
     */
    data object Finish : EmergencyLogoutUiEffect
}

