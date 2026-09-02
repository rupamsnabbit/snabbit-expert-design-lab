package com.snabbit.runner.shared.features.kavach.shared.ui.contracts

import com.snabbit.runner.shared.core.network.AppErrorType
import com.snabbit.runner.shared.features.kavach.shield.domain.KavachPermissionResult

/** User actions on the Kavach home skeleton. */
sealed interface SafetyHomeIntent {
    /** Shield card → "Activate" (opens the consent sheet). */
    data object Activate : SafetyHomeIntent

    /** Legacy card-consent → agree (protection turns on). No production UI dispatches it (consent moved
     *  to Home); retained as the direct-activate() entry the permission tests drive. */
    data object ConfirmConsent : SafetyHomeIntent

    /** Keep-phone info sheet → "Got it" (proceed to activation). */
    data object ConfirmKeepPhone : SafetyHomeIntent

    /** Dismiss the visible sheet (close button / scrim). */
    data object DismissSheet : SafetyHomeIntent

    /** SOS action → raise a manual SOS (shows the alert). */
    data object OpenSos : SafetyHomeIntent

    /** SOS alert → "I'm in danger" (confirm → active screen). */
    data object ConfirmSos : SafetyHomeIntent

    /** SOS alert → "I'm safe" (deny → restore). */
    data object DenySos : SafetyHomeIntent

    /** Retry after a "no storage" condition. */
    data object RetryStorage : SafetyHomeIntent

    /** Transient error consumed by the UI (D2 clear-intent). */
    data object ErrorShown : SafetyHomeIntent

    /** Permission-blocked dialog consumed by the UI (D2 clear-intent / "Not now"). */
    data object PermissionBlockShown : SafetyHomeIntent

    /** Ack the "SOS already in progress" transient flag. */
    data object SosInProgressShown : SafetyHomeIntent

    /** Permission dialog (soft Denied) → re-request mic/location. */
    data object RetryPermission : SafetyHomeIntent

    /** Permission dialog (NeedsSettings) → open the app's OS settings. */
    data object OpenAppSettings : SafetyHomeIntent
}

/** Kavach protection state rendered by the card (before / after activation). */
enum class ProtectionState { IDLE, ACTIVE }

/** The overlay sheet currently showing, if any. */
enum class SafetySheet { KEEP_PHONE, BATTERY_LOW }

/**
 * Immutable UI state for the Kavach home skeleton. The overlay [sheet] and the
 * transient [error] are nullable fields (D2), not navigation destinations — navigation
 * goes through the injected `NavigationController`, not a Contract `SideEffect` (see
 * core-facts.md D2). This feature uses no `Channel`-based side-effects by design.
 */
data class SafetyHomeUiState(
    val sheet: SafetySheet? = null,
    val noStorage: Boolean = false,
    /** SOS alert ("Are you in danger?") overlay — shown while a raised SOS awaits confirm/deny. */
    val sosAlertVisible: Boolean = false,
    /** Plugin-mirrored state (6c): drives the card visuals. `protectionState` is ACTIVE ⟺ recording. */
    val recording: Boolean = false,
    val monitoring: Boolean = false,
    val sosMode: Boolean = false,
    /** Plays the one-shot Kavach activation Lottie over the card (auto-cleared after the clip). */
    val activationLottiePlaying: Boolean = false,
    val error: AppErrorType? = null,
    /** Non-null when activation was blocked on mic/location — drives the permission dialog. */
    val permissionResult: KavachPermissionResult? = null,
    /** True (transient) when the runner tapped SOS while one is already live — surface "SOS already
     *  in progress" instead of silently doing nothing. Cleared by [SafetyHomeIntent.SosInProgressShown]. */
    val sosInProgress: Boolean = false,
) {
    /** Derived from [recording] (ACTIVE ⟺ recording) — computed, not stored, to avoid two-signal drift. */
    val protectionState: ProtectionState get() = if (recording) ProtectionState.ACTIVE else ProtectionState.IDLE
}
