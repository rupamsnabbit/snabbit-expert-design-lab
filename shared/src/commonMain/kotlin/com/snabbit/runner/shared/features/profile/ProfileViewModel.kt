package com.snabbit.runner.shared.features.profile

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.snabbit.runner.shared.core.remoteconfig.RemoteConfigGateway
import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.core.runnerstate.RunnerStateStore
import com.snabbit.runner.shared.features.loan.domain.usecase.GetLoanDetailsUseCase
import com.snabbit.runner.shared.features.pan.domain.usecase.UpdatePanUseCase
import com.snabbit.runner.shared.features.periodleave.PeriodLeaveStore
import com.snabbit.runner.shared.features.profile.domain.VishwaasBannerConfig
import com.snabbit.runner.shared.features.profile.domain.model.RunnerProfile
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * Drives the Profile screen.
 *
 * A **Compose-Multiplatform [ViewModel]** (`org.jetbrains.androidx.lifecycle`) —
 * obtained via `viewModel { }` in the home-shell's `nativeScreen<ProfileRoot>`
 * registration, so it is scoped to the Profile tab's Nav3 entry and survives tab
 * switches (Home ↔ Profile). `commonMain` / iOS-safe.
 *
 * Loads the runner profile ([GetProfileUseCase] → `GET api/v1/runners/me`) once on
 * open; [ProfileUiIntent.Load] retries after an error and [ProfileUiIntent.Refresh]
 * backs pull-to-refresh. Every action flows through [onIntent] (single input
 * channel). Coroutines run on [viewModelScope]; a fetch failure maps to
 * [ProfileUiState.errorMessage] (cancellation propagates — not swallowed).
 */
class ProfileViewModel(
    private val profileStore: RunnerProfileStore,
    private val strings: ProfileStrings,
    /**
     * Opens an existing Flutter page via the nav module's keep-host round trip.
     * Supplied by the `:app` registration (which owns the `NavigationController` +
     * recreate key/args); defaults to a no-op so tests and previews need no nav.
     */
    private val openFlutterRoute: (route: String, args: Map<String, String>) -> Unit = { _, _ -> },
    /**
     * Opens the native Language screen via the nav module, passing the runner's
     * current language. Supplied by the `:app` registration; no-op default.
     */
    private val openLanguage: (currentLanguage: String?) -> Unit = { },
    /**
     * Fires an analytics event (name + props) — wired by `:app` to the KMP
     * `AnalyticsTracker` (routes to Mixpanel/CleverTap via the route table).
     * No-op default so tests and previews need no analytics stack.
     */
    private val trackEvent: (name: String, props: Map<String, Any?>) -> Unit = { _, _ -> },
    /**
     * Reads Firebase Remote Config bool flags (mirrored from Flutter via the
     * `RemoteConfigHostApi` bridge into the KMP store). Defaults to returning the
     * caller's fallback, so tests/previews need no RC. Gates: Monthly earnings
     * (`expert_show_earnings`, default true) + Refer & earn → webview
     * (`expert_is_referrals_v2_enabled`, default false).
     */
    private val remoteConfig: RemoteConfigGateway = RemoteConfigGateway { _, default -> default },
    /**
     * Bridge-fed period-leave availability for the header chip — Dart owns the
     * `period_leave/availability` fetch and pushes it; KMP just observes (no native call).
     * Null in tests/previews → the chip is simply never shown; supplied by `:app` from Koin.
     */
    private val periodLeaveStore: PeriodLeaveStore? = null,
    /**
     * Fetches loan details for the Get-loan bottom sheet. Null in tests/previews →
     * the sheet shows its error state; supplied by the `:app` registration from Koin.
     */
    private val getLoanDetails: GetLoanDetailsUseCase? = null,
    /**
     * Opens an external URL (loan vendor page / ePAN portal) outside the app — wired
     * by `:app` to an Android `ACTION_VIEW` intent. Returns whether it actually
     * launched, so the loan flow can log the real `success` + snackbar on failure
     * (Flutter parity). Default `false` (no browser in tests/previews).
     */
    private val openExternalUrl: (url: String) -> Boolean = { false },
    /**
     * Submits the PAN for the PAN nudge sheet. Null in tests/previews → submit is a
     * no-op; supplied by the `:app` registration from Koin.
     */
    private val updatePan: UpdatePanUseCase? = null,
    /**
     * Runs the Flutter-side "silent notifications" action (stop notifications +
     * audio) — wired by `:app` to a method-channel call into Flutter. No-op default.
     */
    private val onSilentNotifications: () -> Unit = { },
    /**
     * Sets the Flutter profile's transient `panCardUnavailable` flag when the runner
     * taps "Create ePAN" — parity with the drawer sheet, which sets it before opening
     * the portal (suppresses PAN/TDS nags until the next refresh). Wired by `:app` to
     * the `ProfileActions` bridge; no-op default.
     */
    private val onPanCardUnavailable: () -> Unit = { },
    /**
     * Bridge-fed `current_state` envelope — the only thing the Profile tab reads from it is
     * `widget_name`, to gate the Emergency-logout tile. Null in tests/previews → the tile is
     * never shown; supplied by `:app` from Koin.
     */
    private val runnerStateStore: RunnerStateStore? = null,
    /** Debug build flag (from `:app`) — gates the Debug Menu tile (Flutter's `kDebugMode`). */
    isDebug: Boolean = false,
) : ViewModel() {

    private val _uiState = MutableStateFlow(ProfileUiState(isDebug = isDebug))
    val uiState: StateFlow<ProfileUiState> = _uiState.asStateFlow()

    // One-shot effects (snackbars) — a SharedFlow so a re-collector doesn't replay.
    private val _effects = MutableSharedFlow<ProfileUiEffect>(extraBufferCapacity = 4)
    val effects: SharedFlow<ProfileUiEffect> = _effects.asSharedFlow()

    init {
        observeProfile()
        observePeriodLeave()
        observeRunnerState()
        // Seed on open only if Dart hasn't pushed at all yet (still Loading) — e.g. a warm
        // start where `runnersMeSetup` didn't re-run this session, so there's no launch push.
        // Asks Dart to fetch + push: one call, skipped when the launch push already populated
        // the store (no double API), and NOT fired on Error (that shows the error + Retry,
        // not an auto-retry).
        if (profileStore.state.value is ProfileBridgeState.Loading) {
            viewModelScope.launch { profileStore.requestRefresh() }
        }
    }

    /**
     * Observe the bridge-fed [RunnerProfileStore] and map it to the UI. Dart owns the
     * single `runners/me` fetch and pushes the result (success or error) — KMP does not
     * fetch it natively (that would double the API load). Dart re-pushes on every profile
     * mutation (add-bank / Aadhaar re-KYC / PAN), so a cleared nudge disappears here with
     * no extra call. Error is a pushed state, so a failed Dart fetch shows the error
     * screen immediately (no timeout).
     */
    private fun observeProfile() {
        viewModelScope.launch {
            profileStore.state.collect { state ->
                when (state) {
                    ProfileBridgeState.Loading ->
                        _uiState.update { it.copy(isLoading = true, errorMessage = null) }
                    is ProfileBridgeState.Content -> {
                        val earnings = showEarningsFlag()
                        _uiState.update {
                            it.copy(
                                isLoading = false,
                                isRefreshing = false,
                                profile = state.profile,
                                showEarnings = earnings,
                                referralsV2Enabled = referralsV2Flag(),
                                errorMessage = null,
                            )
                        }
                        logSidebarLoadOnce(state.profile, earnings)
                        resolveVishwaasBanner(state.profile)
                    }
                    is ProfileBridgeState.Error ->
                        _uiState.update { it.copy(isLoading = false, errorMessage = strings.errorMessage) }
                }
            }
        }
    }

    /** Observe the bridge-fed period-leave chip data (secondary; null → chip absent). */
    private fun observePeriodLeave() {
        val store = periodLeaveStore ?: return
        viewModelScope.launch {
            store.availability.collect { availability ->
                _uiState.update { it.copy(periodLeave = availability) }
            }
        }
    }

    /**
     * Gate the Emergency-logout tile on the runner's live `current_state` — visible only
     * while on shift ([EMERGENCY_LOGOUT_STATES]), hidden everywhere else (pre-shift
     * attendance, on a job, suspended, see-you-tomorrow, …). The tile reflects the change
     * live: the store replays its current value to this collector on mount and re-emits on
     * every Dart push, so a shift that ends while the Profile tab is open hides the tile.
     */
    private fun observeRunnerState() {
        val store = runnerStateStore ?: return
        viewModelScope.launch {
            store.state.collect { state ->
                _uiState.update { it.copy(canEmergencyLogout = state?.widgetName in EMERGENCY_LOGOUT_STATES) }
            }
        }
    }

    /** The single input channel — every screen action flows through here. */
    fun onIntent(intent: ProfileUiIntent) {
        when (intent) {
            ProfileUiIntent.Load -> load()
            ProfileUiIntent.Refresh -> refresh()
            is ProfileUiIntent.OpenFlutterRoute -> openFlutterRoute(intent.route, intent.args)
            ProfileUiIntent.OpenLanguage -> openLanguage(_uiState.value.profile?.languagePreference)
            ProfileUiIntent.VishwaasBannerClicked -> onVishwaasBannerClicked()
            ProfileUiIntent.ShowLoanSheet -> showLoanSheet()
            ProfileUiIntent.LoanSheetDismissed -> _uiState.update { it.copy(loanSheet = null) }
            ProfileUiIntent.LoanSheetRetry -> fetchLoan()
            ProfileUiIntent.LoanUnderstoodClicked -> onLoanUnderstood()
            ProfileUiIntent.LoanViewDetailsClicked -> onLoanViewDetails()
            ProfileUiIntent.ShowPanSheet -> _uiState.update { it.copy(panSheet = PanSheetState()) }
            ProfileUiIntent.PanSheetDismissed -> _uiState.update { it.copy(panSheet = null) }
            is ProfileUiIntent.PanInputChanged -> onPanInputChanged(intent.value)
            ProfileUiIntent.PanSubmit -> submitPan()
            ProfileUiIntent.CreatePanClicked -> {
                onPanCardUnavailable() // drawer parity: mark PAN unavailable before the portal
                openExternalUrl(EPAN_PORTAL_URL)
            }
            ProfileUiIntent.SilentNotificationsClicked -> {
                // Fire the analytics here (route table → CleverTap); the Flutter bridge
                // only runs the stop-notifications/audio side effects (no double event).
                trackEvent(EVENT_SILENT_NOTIF, mapOf("drawer" to "Silent notification feature used"))
                onSilentNotifications()
            }
            ProfileUiIntent.ShowEmergencyLogout -> _uiState.update { it.copy(showEmergencyLogout = true) }
            ProfileUiIntent.EmergencyLogoutDismissed -> _uiState.update { it.copy(showEmergencyLogout = false) }
            is ProfileUiIntent.MenuItemTapped ->
                trackEvent(EVENT_CTA_CLICK, mapOf("cta_text" to intent.cta, "section" to intent.section))
            is ProfileUiIntent.NudgesShown ->
                trackEvent(
                    EVENT_SPOTLIGHT_LOAD,
                    mapOf(
                        "nudge_ids" to intent.nudgeTypes.joinToString(","),
                        "nudge_count" to intent.nudgeTypes.size,
                    ),
                )
            is ProfileUiIntent.NudgeTapped ->
                trackEvent(EVENT_SPOTLIGHT_CTA, mapOf("nudge_id" to intent.nudgeType))
        }
    }

    /**
     * Retry after an error — ask Dart to re-fetch `runners/me`; [observeProfile] maps the
     * result (Content clears the error; another Error re-shows it). Optimistically show the
     * spinner while Dart works.
     */
    private fun load() {
        _uiState.update { it.copy(isLoading = true, errorMessage = null) }
        viewModelScope.launch { profileStore.requestRefresh() }
    }

    /**
     * Pull-to-refresh — ask Dart to re-fetch `runners/me` (+ period-leave) and suspend
     * until it finishes, so the spinner clears exactly when Dart is done (even if the data
     * is unchanged or the re-fetch failed). The fresh profile flows in via [observeProfile];
     * a failed re-fetch keeps the current content on screen (the store's error push no-ops
     * while Content exists).
     */
    private fun refresh() {
        viewModelScope.launch {
            _uiState.update { it.copy(isRefreshing = true) }
            profileStore.requestRefresh()
            _uiState.update { it.copy(isRefreshing = false) }
        }
    }

    // Remote Config gates (mirrored from Flutter). Defaults match the Dart side.
    private fun showEarningsFlag() = remoteConfig.getBool(ProfileRouteDecider.RC_SHOW_EARNINGS, default = true)
    private fun referralsV2Flag() = remoteConfig.getBool(ProfileRouteDecider.RC_REFERRALS_V2, default = false)

    // ── Vishwaas rate-card banner ─────────────────────────────────────────────
    // Mirrors Flutter's UserProfileProvider.showVishwaasBanner (4-condition gate)
    // + VishwaasBannerRemoteConfig (per-language drawer image from the RC JSON).
    private var vishwaasImpressionKey: String? = null

    /** Resolve the banner URL from the gate + RC config, and log the impression once. */
    private fun resolveVishwaasBanner(profile: RunnerProfile) {
        val url = vishwaasBannerUrl(profile)
        _uiState.update { it.copy(vishwaasBannerUrl = url) }
        if (url == null) return
        // One impression per (language|url) — parity with the Flutter banner widget.
        val key = "${profile.languagePreference.orEmpty()}|$url"
        if (key == vishwaasImpressionKey) return
        vishwaasImpressionKey = key
        // switch-RC impression + the app-wide generic-banner impression (distinct
        // events / dashboards — both fired for this banner, as in Flutter).
        trackEvent(EVENT_BANNER_LOAD, vishwaasProps(profile))
        trackEvent(EVENT_GENERIC_BANNER_IMPRESSION, bannerBaseProps())
    }

    /** The 4-condition gate (drawer_menu parity) + per-language drawer image; null → no banner. */
    private fun vishwaasBannerUrl(profile: RunnerProfile): String? {
        if (remoteConfig.getBool(PREF_ALREADY_DID_V2_OPT_IN, default = false)) return null // ① opted-in locally
        if (!remoteConfig.getBool(RC_ENABLE_VISHWAAS, default = false)) return null          // ② RC flag off
        if (profile.hasLowerEarningsInNewRateCard) return null                                // ④ earns less on v2
        if (!profile.isRateCardV1) return null                                                // ③ already on v2
        val config = VishwaasBannerConfig.parse(
            primary = remoteConfig.getString(RC_VISHWAAS_BANNER, default = ""),
            legacyFlat = remoteConfig.getString(RC_VISHWAAS_DRAWER_BANNER, default = ""),
        )
        return config?.drawer?.resolveImageUrl(profile.languagePreference)
    }

    private fun onVishwaasBannerClicked() {
        // switch-RC CTA-click + the app-wide generic banner_clicked (distinct events).
        _uiState.value.profile?.let { trackEvent(EVENT_BANNER_CTA, vishwaasProps(it)) }
        trackEvent(EVENT_BANNER_CLICKED, bannerBaseProps())
        openFlutterRoute(
            ProfileFlutterRoutes.APP_WEB_VIEW,
            mapOf(
                "webviewPath" to ProfileFlutterRoutes.WEBVIEW_VISHWAAS_RATE_CARD,
                "title" to "Rate card",
            ),
        )
    }

    private fun bannerBaseProps(): Map<String, Any?> = mapOf(
        "banner_id" to VISHWAAS_BANNER_ID,
        "placement" to VISHWAAS_PLACEMENT,
    )

    /** Switch-RC cohort props (Flutter `switchRcCommonProps`) + banner id/placement. */
    private fun vishwaasProps(p: RunnerProfile): Map<String, Any?> = bannerBaseProps() + mapOf(
        "rc_id" to p.rateCard,
        "rate_card_version" to if (p.isRateCardV1) "v1" else "v2",
        "rate_card_optin_month" to p.rateCardOptinMonth,
        "has_lower_earnings_in_new_rate_card" to p.hasLowerEarningsInNewRateCard,
        "city" to p.clusterId,
        "region_id" to p.regionId,
        "banner_variant" to p.languagePreference,
    )

    // ── Get-loan bottom sheet ─────────────────────────────────────────────────
    // Mirrors Flutter's showLoanUnifiedSheet: fetch loan_details, then show the
    // early-payout / loan-processed card, or (eligible) open the vendor URL directly.
    private fun showLoanSheet() {
        trackEvent(EVENT_LOAN_BANNER_CLICK, loanBaseProps())
        fetchLoan()
    }

    private fun fetchLoan() {
        val useCase = getLoanDetails
        if (useCase == null) {
            _uiState.update { it.copy(loanSheet = LoanSheetState.Error) }
            return
        }
        _uiState.update { it.copy(loanSheet = LoanSheetState.Loading) }
        viewModelScope.launch {
            when (val result = useCase()) {
                is Result.Ok -> {
                    val loan = result.value
                    when {
                        loan.isEarlyPayoutTaken -> {
                            _uiState.update { it.copy(loanSheet = LoanSheetState.EarlyPayout) }
                            trackEvent(EVENT_LOAN_SHEET_IMPRESSION, loanStateProps("early_payout"))
                        }
                        loan.isLoanProcessed -> {
                            _uiState.update { it.copy(loanSheet = LoanSheetState.LoanProcessed(loan.vendorUrl)) }
                            trackEvent(EVENT_LOAN_SHEET_IMPRESSION, loanStateProps("loan_processed"))
                        }
                        // Eligible → no interstitial card; open the vendor page directly.
                        else -> {
                            _uiState.update { it.copy(loanSheet = null) }
                            openVendorUrl(loan.vendorUrl)
                        }
                    }
                }
                is Result.Err -> _uiState.update { it.copy(loanSheet = LoanSheetState.Error) }
            }
        }
    }

    private fun onLoanUnderstood() {
        trackEvent(EVENT_LOAN_SHEET_ACTION, loanActionProps("understood", "early_payout"))
        _uiState.update { it.copy(loanSheet = null) }
    }

    private fun onLoanViewDetails() {
        val url = (_uiState.value.loanSheet as? LoanSheetState.LoanProcessed)?.vendorUrl
        trackEvent(EVENT_LOAN_SHEET_ACTION, loanActionProps("view_details", "loan_processed"))
        _uiState.update { it.copy(loanSheet = null) }
        if (url != null) openVendorUrl(url)
    }

    private fun openVendorUrl(url: String) {
        // Blank vendor URL → treat as an open failure (Flutter attempts launchUrl("")
        // and shows the same snackbar), so the runner isn't left with a dead button.
        val success = if (url.isBlank()) false else openExternalUrl(url)
        trackEvent(EVENT_LOAN_EXTERNAL_URL, loanBaseProps() + mapOf("url" to url, "success" to success))
        if (!success) _effects.tryEmit(ProfileUiEffect.ShowSnackbar(strings.loanUrlOpenFailed))
    }

    // Common loan-event props (Flutter `_getCommonAttributes` + `source`): runner_id +
    // the "drawer" source literal, merged into every loan analytics event.
    private fun loanBaseProps(): Map<String, Any?> =
        mapOf("runner_id" to _uiState.value.profile?.expertId, "source" to LOAN_SOURCE)

    private fun loanStateProps(state: String): Map<String, Any?> =
        loanBaseProps() + mapOf("state" to state)

    private fun loanActionProps(action: String, state: String): Map<String, Any?> =
        loanBaseProps() + mapOf("action" to action, "state" to state)

    // ── PAN-update bottom sheet ───────────────────────────────────────────────
    // Mirrors Flutter's UploadPanModalSheetV2: PAN field → regex validate → POST;
    // on success refresh the profile (the PAN nudge disappears) and dismiss.
    private fun onPanInputChanged(value: String) {
        _uiState.update { state ->
            val sheet = state.panSheet ?: return
            // Upper-case + cap at 10 (Flutter maxLength 10 + toUpperCase); recompute
            // validity (gates the Continue button) and clear any prior server error.
            val pan = value.uppercase().take(10)
            state.copy(panSheet = sheet.copy(panInput = pan, isPanValid = PAN_REGEX.matches(pan), error = null))
        }
    }

    private fun submitPan() {
        val sheet = _uiState.value.panSheet ?: return
        // Continue is gated on validity (Flutter parity); ignore stray submits.
        if (!sheet.isPanValid) return
        val useCase = updatePan ?: return
        _uiState.update { it.copy(panSheet = sheet.copy(isSubmitting = true, error = null)) }
        viewModelScope.launch {
            when (val result = useCase(sheet.panInput)) {
                is Result.Ok -> {
                    _uiState.update { it.copy(panSheet = null) } // dismiss
                    refresh() // re-fetch profile → PAN nudge gone
                }
                is Result.Err -> _uiState.update { state ->
                    state.copy(panSheet = state.panSheet?.copy(isSubmitting = false, error = result.error))
                }
            }
        }
    }

    // ── Analytics ────────────────────────────────────────────────────────────
    // Parity with the Flutter drawer's `profileSectionSidebarLoad` (fired once
    // when the sidebar opened). We fire once per VM instance after the first
    // successful load — not on refresh — so a pull-to-refresh doesn't re-log.
    private var sidebarLoadLogged = false

    private fun logSidebarLoadOnce(profile: RunnerProfile, showEarnings: Boolean) {
        if (sidebarLoadLogged) return
        sidebarLoadLogged = true
        val sidebar = sidebarProps(profile, showEarnings)
        trackEvent(EVENT_SIDEBAR_LOAD, sidebar)
        // expert-v2 spec event (additive to the legacy sidebar-load).
        trackEvent(EVENT_SCREEN_LOAD, profileScreenLoadProps(profile, sidebar))
    }

    /** `profile_screen_load` props — the spec-named subset; `items_visible` reuses the
     *  sidebar `list_visible` list. */
    private fun profileScreenLoadProps(p: RunnerProfile, sidebar: Map<String, Any?>): Map<String, Any?> {
        val nudges = buildList {
            if (p.hasBankNudge) add("bank")
            if (p.hasAadhaarRekycNudge) add("aadhaar_rekyc")
            if (p.hasPanNudge) add("pan")
            if (p.hasPanAadhaarNudge) add("pan_aadhaar")
        }
        return mapOf(
            "expert_id" to p.expertId,
            "tier" to p.tier,
            "rating" to p.currentMonthRating,
            "items_visible" to sidebar["list_visible"],
            "nudge_count" to nudges.size,
            "nudge_ids" to nudges.joinToString(","),
            "bank_details_missing" to p.hasBankNudge,
            "pan_missing" to p.hasPanNudge,
        )
    }

    /**
     * Props mirror the Flutter drawer's `_sidebarContextProps` exactly, including
     * the `list_visible` keys and their gates (drawer_menu.dart:100-135). The one
     * omission is `period_leave_available` — the period-leave call returns *after*
     * this LOAD event fires (it's a separate, secondary fetch), so it isn't ready here.
     */
    private fun sidebarProps(p: RunnerProfile, showEarnings: Boolean): Map<String, Any?> = mapOf(
        "insurance_tier" to p.tier,
        "current_month_rating" to p.currentMonthRating,
        "list_visible" to buildList {
            add("identity_card")
            if (showEarnings) add("earnings")
            if (p.isRateCardV2Effective) add("rate_card")
            if (p.showEarlyPayout) add("early_payout")
            add("refer_and_earn")
            if (p.showTransactionHistory) add("transaction_history")
            if (p.showSeva) add("seva")
            if (p.showMerchStore) add("merch_store")
            add("claim_insurance")
            add("leaves")
            add("language")
            if (p.isLoanEligible) add("get_loan")
            if (p.hasPanNudge) add("pan_nudge")
            if (p.hasBankNudge) add("bank_nudge")
            if (p.hasPanAadhaarNudge) add("pan_aadhar_link_nudge")
        },
        "pan_nudges_visible" to (p.hasPanNudge || p.hasBankNudge || p.hasPanAadhaarNudge),
        "pan_nudge_visible" to p.hasPanNudge,
        "bank_nudge_visible" to p.hasBankNudge,
        "pan_aadhar_link_nudge_visible" to p.hasPanAadhaarNudge,
    )

    private companion object {
        const val EVENT_SIDEBAR_LOAD = "profile_section_sidebar_load"
        // expert-v2 Profile spec events (additive; through the same trackEvent seam).
        const val EVENT_SCREEN_LOAD = "profile_screen_load"
        const val EVENT_CTA_CLICK = "profile_screen_cta_click"
        const val EVENT_SPOTLIGHT_LOAD = "spotlight_nudge_screen_load"
        const val EVENT_SPOTLIGHT_CTA = "spotlight_nudge_screen_cta_click"
        // Vishwaas banner — RC keys (bool + string) + the local opt-in pref key.
        const val RC_ENABLE_VISHWAAS = "expert_enable_vishwaas_rate_card_banner"
        const val RC_VISHWAAS_BANNER = "expert_vishwaas_banner"
        const val RC_VISHWAAS_DRAWER_BANNER = "expert_vishwaas_drawer_banner"
        const val PREF_ALREADY_DID_V2_OPT_IN = "already_did_v2_opt_in"
        // Vishwaas banner — switch-RC analytics (route table → Mixpanel + CleverTap)
        // + the app-wide generic-banner events (separate feature, keyed by banner_id).
        const val EVENT_BANNER_LOAD = "switch_rc_profile_page_banner_load"
        const val EVENT_BANNER_CTA = "switch_rc_profile_page_banner_cta_click"
        const val EVENT_GENERIC_BANNER_IMPRESSION = "generic_banner_impression"
        const val EVENT_BANNER_CLICKED = "banner_clicked"
        const val VISHWAAS_BANNER_ID = "vishwaas_drawer"
        const val VISHWAAS_PLACEMENT = "drawer"
        // Get-loan analytics (all → CleverTap via route table). `source` kept as the
        // Flutter literal "drawer" for dashboard continuity.
        const val EVENT_LOAN_BANNER_CLICK = "loan_banner_click"
        const val EVENT_LOAN_SHEET_IMPRESSION = "loan_bottom_sheet_impression"
        const val EVENT_LOAN_SHEET_ACTION = "loan_bottom_sheet_action"
        const val EVENT_LOAN_EXTERNAL_URL = "loan_external_url_launched"
        const val LOAN_SOURCE = "drawer"
        // PAN — client-side validation (mirrors Dart's _isValidPanCard regex).
        val PAN_REGEX = Regex("^[A-Z]{5}[0-9]{4}[A-Z]$")
        // "Create ePAN" opens the income-tax ePAN portal (hardcoded in Flutter too).
        const val EPAN_PORTAL_URL =
            "https://eportal.incometax.gov.in/iec/foservices/#/pre-login/instant-e-pan/getNewEpan"
        // Silent-notifications analytics (route table → CleverTap).
        const val EVENT_SILENT_NOTIF = "silent_notification_feature_used"
        // `current_state` widget_names where the Emergency-logout tile is offered:
        // searching-for-jobs and end-of-shift. Everything else — pre-shift attendance,
        // any RUNNER_JOB_* / RUNNER_NEW_JOB, lunch, suspended — hides it.
        // ponytail: a flat allowlist, not a projector — the two existing projectors
        // (ShiftProjector's phase, job's internal `toJob()`) don't expose this cut, and an
        // unknown/new widget_name defaults to hidden, which is the safe direction.
        // Promote to a shared selector if a second feature needs the same gate.
        val EMERGENCY_LOGOUT_STATES = setOf("RUNNER_WAIT_HOTSPOT", "RUNNER_LOGOUT")
    }
}
