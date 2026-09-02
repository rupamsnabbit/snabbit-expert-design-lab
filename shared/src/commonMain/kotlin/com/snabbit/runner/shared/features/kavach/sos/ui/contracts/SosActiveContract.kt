package com.snabbit.runner.shared.features.kavach.sos.ui.contracts

import com.snabbit.runner.shared.core.network.AppErrorType

/** User actions on the SOS-active ("Help is on the way") screen. */
sealed interface SosActiveIntent {
    /** "Call SOS Team". */
    data object CallSosTeam : SosActiveIntent

    /** "I am safe, end SOS" → end SOS and return. */
    data object MarkSafe : SosActiveIntent

    /** Transient error consumed by the UI (D2 clear-intent). */
    data object ErrorShown : SosActiveIntent
}

/**
 * Immutable UI state for the SOS-active screen. Mostly static content; [ending]
 * guards the "I am safe" action while endSos is in flight.
 */
data class SosActiveUiState(
    val ending: Boolean = false,
    val error: AppErrorType? = null,
)
