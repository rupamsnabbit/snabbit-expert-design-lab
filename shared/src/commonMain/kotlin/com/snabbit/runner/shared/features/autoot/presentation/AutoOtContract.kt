package com.snabbit.runner.shared.features.autoot.presentation

import com.snabbit.runner.shared.core.network.AppErrorType
import com.snabbit.runner.shared.features.autoot.domain.model.AutoOtDetails

/** The step the Auto-OT sheet is showing. A `null` [AutoOtUiState.step] = sheet not shown. */
enum class AutoOtStep { Offer, Confirm, Loading, Success, Expired, Failure }

/**
 * Render state for the Auto-OT sheet — full parity with the Flutter `AutoOtState`
 * machine (idle == `step == null`, so the overlay renders nothing).
 */
data class AutoOtUiState(
    val step: AutoOtStep? = null,
    val details: AutoOtDetails? = null,
    /** True while the accept call is in flight — disables the CTA. */
    val submitting: Boolean = false,
    /** Accept-failure error (set on [AutoOtStep.Failure]) — selects the error copy. */
    val error: AppErrorType? = null,
)

/** User actions on the Auto-OT sheet. */
sealed interface AutoOtUiIntent {
    /** Offer "Confirm OT" → the confirm step. */
    data object Confirm : AutoOtUiIntent

    /** Confirm "Confirm" → accept the OT. */
    data object Submit : AutoOtUiIntent

    /** Failure "Retry" → re-attempt accept. */
    data object Retry : AutoOtUiIntent

    /**
     * Sheet ✕ / scrim / back. The redesign has no in-body decline button, so closing the **offer**
     * via ✕ IS the reject (REJECTED + `ot_rejected`) — see [AutoOtViewModel]. Closing later steps
     * dismisses (DISMISSED, no analytics).
     */
    data object Dismiss : AutoOtUiIntent

    /** Success / Expired "Go back" / "OK" → dismiss (no API). */
    data object Acknowledge : AutoOtUiIntent
}
