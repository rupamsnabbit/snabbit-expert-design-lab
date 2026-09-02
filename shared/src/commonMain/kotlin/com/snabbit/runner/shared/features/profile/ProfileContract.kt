package com.snabbit.runner.shared.features.profile

import com.snabbit.runner.shared.features.periodleave.domain.model.PeriodLeaveAvailability
import com.snabbit.runner.shared.features.profile.domain.model.RunnerProfile

/**
 * Render state for the Profile screen.
 *
 * Three-state model (see [ProfileScreen]):
 *  - initial load in flight → [isLoading] true (spinner)
 *  - load failure           → [errorMessage] set + [profile] null (error + Retry)
 *  - content                → [profile] non-null
 *
 * [isRefreshing] drives the pull-to-refresh spinner; a refresh failure keeps the
 * existing [profile] on screen (doesn't flip to the error state).
 *
 * The screen reads [profile]'s fields to render the header, section tiles (via the
 * visibility gates), and the nudge carousel. [showEarnings] and [referralsV2Enabled]
 * are Remote Config gates mirrored from Flutter (Monthly earnings tile; Refer & earn
 * → webview vs native), defaulting to the same safe values as the Dart side.
 *
 * [periodLeave] backs the header's period-leave chip; it's a *separate* fetch
 * (`period_leave/availability`) that lands after the profile, so it's null until it
 * returns (and stays null if that call fails — the chip just doesn't show).
 */
data class ProfileUiState(
    val isLoading: Boolean = true,
    val isRefreshing: Boolean = false,
    val profile: RunnerProfile? = null,
    val showEarnings: Boolean = true,
    val referralsV2Enabled: Boolean = false,
    /** Debug build → shows the Debug Menu tile (mirrors Flutter's `kDebugMode` gate). */
    val isDebug: Boolean = false,
    val periodLeave: PeriodLeaveAvailability? = null,
    /**
     * Resolved image URL for the Vishwaas rate-card banner, or null when the
     * banner shouldn't show (gate failed / no per-language image). Computed after
     * the profile load from the RC config + gate (see [ProfileViewModel]).
     */
    val vishwaasBannerUrl: String? = null,
    /** Non-null when the Get-loan bottom sheet is open (its current sub-state). */
    val loanSheet: LoanSheetState? = null,
    /** Non-null when the PAN-update bottom sheet is open (its form state). */
    val panSheet: PanSheetState? = null,
    /**
     * True while the emergency-logout modal flow is open (entry: the "Emergency
     * logout" menu tile). The flow owns its own VM (built in `ProfileTabContent`),
     * so this is just the open/closed flag on the Profile axis.
     */
    val showEmergencyLogout: Boolean = false,
    /**
     * Gates the "Emergency logout" *tile* (distinct from [showEmergencyLogout], which is
     * the open/closed flag of the flow it opens). True only while the runner is on shift
     * — see `EMERGENCY_LOGOUT_STATES` in [ProfileViewModel]. Defaults false, so the tile
     * stays hidden until a `current_state` envelope says otherwise.
     */
    val canEmergencyLogout: Boolean = false,
    val errorMessage: String? = null,
)

/**
 * Form state for the PAN-update bottom sheet (drawer parity — `UploadPanModalSheetV2`).
 * [isPanValid] drives the Continue button's enabled state (the Flutter sheet disables
 * it until the PAN is valid, rather than showing an inline validation error).
 */
data class PanSheetState(
    val panInput: String = "",
    val isPanValid: Boolean = false,
    val isSubmitting: Boolean = false,
    val error: String? = null,
)

/**
 * The Get-loan bottom sheet's sub-state (drawer parity — `showLoanUnifiedSheet`).
 * The "eligible/happy" outcome isn't a state — it opens the vendor URL and never
 * shows a card, so it's absent here.
 */
sealed interface LoanSheetState {
    /** Fetching `loan_details`. */
    data object Loading : LoanSheetState

    /** Fetch failed — message + Retry. */
    data object Error : LoanSheetState

    /** Early Payout already taken → loan unavailable this month ("Understood"). */
    data object EarlyPayout : LoanSheetState

    /** Loan already processed → "View Details" opens [vendorUrl]. */
    data class LoanProcessed(val vendorUrl: String) : LoanSheetState
}

/**
 * Every user action on the Profile screen, as data. The screen sends these to
 * [ProfileViewModel.onIntent] — a single input channel, so all state transitions
 * live in one exhaustive `when`.
 */
sealed interface ProfileUiIntent {
    /** Initial load / Retry after an error. */
    data object Load : ProfileUiIntent

    /** Pull-to-refresh — re-fetch without clearing current content. */
    data object Refresh : ProfileUiIntent

    /**
     * Open an existing Flutter page (a `ProfileFlutterRoutes` value) via the nav
     * module's keep-host round trip, so the runner returns to the Profile tab. The
     * actual keep-host call is supplied by the `:app` registration (see
     * [ProfileViewModel]); [args] are optional route arguments.
     */
    data class OpenFlutterRoute(
        val route: String,
        val args: Map<String, String> = emptyMap(),
    ) : ProfileUiIntent

    /**
     * Open the native Language screen (a nav-module destination) — the `:app`
     * registration navigates via `NavigationController` with the runner's current
     * language.
     */
    data object OpenLanguage : ProfileUiIntent

    /**
     * The header Vishwaas banner was tapped — logs the switch-RC CTA-click
     * analytics and opens the Vishwaas rate-card webview (keep-host).
     */
    data object VishwaasBannerClicked : ProfileUiIntent

    // ── Get-loan bottom sheet ──────────────────────────────────────────────────
    /** Get-loan tile tapped — open the sheet (loading) and fetch loan details. */
    data object ShowLoanSheet : ProfileUiIntent

    /** Sheet dismissed (X / scrim / back). */
    data object LoanSheetDismissed : ProfileUiIntent

    /** Retry after a loan-details fetch error. */
    data object LoanSheetRetry : ProfileUiIntent

    /** "Understood" on the early-payout state — dismiss (+ action analytics). */
    data object LoanUnderstoodClicked : ProfileUiIntent

    /** "View Details" on the processed state — open the vendor URL externally. */
    data object LoanViewDetailsClicked : ProfileUiIntent

    // ── PAN-update bottom sheet ────────────────────────────────────────────────
    /** PAN nudge tapped — open the PAN-update sheet. */
    data object ShowPanSheet : ProfileUiIntent

    /** PAN sheet dismissed (X / scrim / back). */
    data object PanSheetDismissed : ProfileUiIntent

    /** PAN field edited (value is upper-cased + capped at 10 for validation/display). */
    data class PanInputChanged(val value: String) : ProfileUiIntent

    /** Submit the entered PAN — POST; on success refresh + dismiss (button gated on validity). */
    data object PanSubmit : ProfileUiIntent

    /** "Create ePAN" link — opens the income-tax ePAN portal externally. */
    data object CreatePanClicked : ProfileUiIntent

    /** Silent-notifications tile — stop notifications/audio (Flutter-side action via bridge). */
    data object SilentNotificationsClicked : ProfileUiIntent

    // ── Emergency logout ──────────────────────────────────────────────────────
    /** "Emergency logout" tile tapped — open the modal emergency-logout flow. */
    data object ShowEmergencyLogout : ProfileUiIntent

    /** Emergency-logout flow finished / dismissed — clear the overlay flag. */
    data object EmergencyLogoutDismissed : ProfileUiIntent

    // ── Analytics-only (no state change) ───────────────────────────────────────
    /** A menu tile / header item was tapped — fires `profile_screen_cta_click`
     *  ([cta] = the tile key, [section] = its section key). */
    data class MenuItemTapped(val cta: String, val section: String) : ProfileUiIntent

    /** The nudge carousel became visible — fires `spotlight_nudge_screen_load`. */
    data class NudgesShown(val nudgeTypes: List<String>) : ProfileUiIntent

    /** A nudge was tapped — fires `spotlight_nudge_screen_cta_click` ([nudgeType] =
     *  bank / aadhaar_rekyc / pan / pan_aadhaar). */
    data class NudgeTapped(val nudgeType: String) : ProfileUiIntent
}

/**
 * One-shot side effects (not state) the screen consumes once — a `SharedFlow`, so a
 * re-collector doesn't replay past effects. Mirrors `HomeUiEffect`.
 */
sealed interface ProfileUiEffect {
    /** Show a transient snackbar; [message] is already localised by the ViewModel. */
    data class ShowSnackbar(val message: String) : ProfileUiEffect
}
