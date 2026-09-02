package com.snabbit.runner.shared.features.home.presentation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.snabbit.runner.shared.features.shift.attendance.domain.repository.AttendanceRepository
import com.snabbit.runner.shared.core.CurrentTimeMs
import com.snabbit.runner.shared.core.Logger
import com.snabbit.runner.shared.core.defaultLogger
import com.snabbit.runner.shared.core.analytics.AnalyticsTracker
import com.snabbit.runner.shared.core.analytics.ErrorAnalytics
import com.snabbit.runner.shared.core.remoteconfig.RemoteConfigGateway
import com.snabbit.runner.shared.core.navigation.NavigationController
import com.snabbit.runner.shared.core.location.LocationProvider
import com.snabbit.runner.shared.core.location.LocationResult
import com.snabbit.runner.shared.core.location.SnabbitLocation
import com.snabbit.runner.shared.core.location.distanceMeters
import com.snabbit.runner.shared.core.permissions.PermissionObserver
import com.snabbit.runner.shared.core.permissions.ServiceType
import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.core.result.RunnerActionError
import com.snabbit.runner.shared.features.gamification.data.GamificationProjector
import com.snabbit.runner.shared.features.gamification.domain.filterForLifecycle
import com.snabbit.runner.shared.features.gamification.domain.model.LifecycleActionTypes
import com.snabbit.runner.shared.features.gamification.presentation.postaction.PostActionCoordinator
import com.snabbit.runner.shared.features.job.data.contact.CallingDataSource
import com.snabbit.runner.shared.features.job.data.contact.CustomerContactLauncher
import com.snabbit.runner.shared.features.job.data.contact.NoOpCustomerContactLauncher
import com.snabbit.runner.shared.features.shift.core.domain.repository.ShiftRepository
import com.snabbit.runner.shared.features.shift.lunch.data.LunchProjector
import com.snabbit.runner.shared.features.shift.lunch.domain.model.BreakColorState
import com.snabbit.runner.shared.features.shift.lunch.domain.model.LunchPhase
import com.snabbit.runner.shared.features.shift.lunch.domain.repository.LunchRepository
import kotlin.coroutines.cancellation.CancellationException
import kotlin.time.Duration.Companion.milliseconds
import kotlin.time.Duration.Companion.seconds
import com.snabbit.runner.shared.features.shift.core.data.ShiftProjector
import com.snabbit.runner.shared.features.home.domain.mapper.attendanceCardsFrom
import com.snabbit.runner.shared.features.shift.core.domain.model.AttendanceStatus
import com.snabbit.runner.shared.features.home.domain.model.Banner
import com.snabbit.runner.shared.features.home.domain.model.HomeBg
import com.snabbit.runner.shared.features.home.domain.model.HomeCard
import com.snabbit.runner.shared.features.home.domain.model.MapFloatingState
import com.snabbit.runner.shared.features.home.domain.model.bg
import com.snabbit.runner.shared.features.home.banners.data.HomeBannersStore
import com.snabbit.runner.shared.features.home.seeyoutomorrow.data.SeeYouTomorrowProjector
import com.snabbit.runner.shared.features.home.suspended.data.SuspendedProjector
import com.snabbit.runner.shared.features.profile.ProfileRouteDecider
import com.snabbit.runner.shared.features.kavach.shared.domain.KavachConsentGate
import com.snabbit.runner.shared.features.profile.RunnerProfileStore
import com.snabbit.runner.shared.features.home.suspended.domain.model.SuspendedInfo
import com.snabbit.runner.shared.features.home.suspended.domain.model.UnsuspendResult
import com.snabbit.runner.shared.features.home.suspended.domain.repository.SuspendedRepository
import com.snabbit.runner.shared.features.home.presentation.ui.MapCoords
import com.snabbit.runner.shared.features.seva.domain.repository.SevaRepository
import com.snabbit.runner.shared.features.shift.core.domain.model.Shift
import com.snabbit.runner.shared.features.shift.core.domain.model.ShiftPhase
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.withTimeoutOrNull
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import com.snabbit.runner.shared.features.kavach.sos.data.gateway.SosVisibilityGateway
import com.snabbit.runner.shared.features.kavach.sos.domain.SosCoordinator
import com.snabbit.runner.shared.features.autoot.data.AutoOtCoordinator
import com.snabbit.runner.shared.features.profile.ProfileBridgeState

/**
 * Drives the Home screen.
 *
 * - **Cards:** projected from [readModel] via [attendanceCardsFrom] into
 *   `heroCards`. No hardcoded seeds.
 * - **Sheets:** axis on [HomeUiState]; opened by user intents only.
 * - **Refresh:** `HomeUiIntent.Load` → `readModel.requestRefresh()`.
 */
class HomeViewModel(
    private val readModel: ShiftProjector,
    private val gamification: GamificationProjector,
    private val attendanceRepository: AttendanceRepository,
    private val shiftRepository: ShiftRepository,
    private val postActionCoordinator: PostActionCoordinator,
    private val lunchReadModel: LunchProjector,
    private val lunchRepository: LunchRepository,
    private val sevaRepository: SevaRepository,
    private val suspendedReadModel: SuspendedProjector,
    private val suspendedRepository: SuspendedRepository,
    private val seeYouTomorrowReadModel: SeeYouTomorrowProjector,
    private val homeBannersStore: HomeBannersStore,
    private val locationProvider: LocationProvider,
    private val analytics: AnalyticsTracker,
    private val currentTimeMs: CurrentTimeMs,
    // Defaults to the platform logger (== Koin's `single<Logger>` binding), so
    // DI/tests need not pass it explicitly — mirrors HelloModule's pattern.
    private val logger: Logger = defaultLogger(),
    initialPhase: ShiftPhase = ShiftPhase.PreShift,
    /** Opens the gold-coins rewards webview (Dart `v1/payouts/rewards?type=gold_coins`).
     *  Wired in [com.snabbit.runner.shared.features.home.di.homeModule] to the
     *  keep-host Flutter handoff; a no-op default keeps previews/tests DI-free. */
    private val openCoinsPage: () -> Unit = {},
    /** Red card pill → red-cards rewards webview, keeping Home alive (mirror of [openCoinsPage];
     *  Dart `WebviewRoutes.payoutsRewardsRedCards`). No-op default keeps previews/tests DI-free. */
    private val openRedCardsPage: () -> Unit = {},
    private val openSaathiSupportPage: () -> Unit = {},
    /** App-scoped SOS coordinator — the top-nav SOS pill raises a manual SOS (job-independent,
     *  contract §3). Nullable so previews/tests stay DI-free; wired in `homeModule`. */
    private val sosCoordinator: SosCoordinator? = null,
    /** Backend SOS-visibility gate (Flutter parity). Nullable → always visible for previews/tests. */
    private val sosVisibility: SosVisibilityGateway? = null,
    /** Dialer seam (`Intent.ACTION_DIAL`) — the FALLBACK for the Saathi pill, used only when the
     *  IVR masked call can't be placed (Flutter `_launchDialerAsFallback`). Wired in [homeModule];
     *  no-op default keeps previews/tests DI-free. */
    private val customerContactLauncher: CustomerContactLauncher = NoOpCustomerContactLauncher,
    /** Masked-call (IVR) seam — the Saathi pill is IVR-first with a dialer fallback, mirroring
     *  Flutter `CallUtils.handleCallInitiation`, which ALWAYS attempts the backend call first.
     *  Required (no no-op default) so production/tests can never silently skip the IVR hop and
     *  regress to dialer-only. Reuses the job-feature `CallingDataSource` single; wired in [homeModule]. */
    private val callingDataSource: CallingDataSource,
    /** Reads the Saathi helpline number from Remote Config ([RC_SAATHI_HELPLINE], with a
     *  baked-in default). No-op default returns each caller default for previews/tests. */
    private val remoteConfig: RemoteConfigGateway = RemoteConfigGateway { _, default -> default },
    /** Read-side Auto-OT orchestrator — receives the START_OT probe after an attendance mark
     *  (Flutter `onAttendanceMarked`). Nullable so previews/tests stay DI-free; wired in `homeModule`. */
    private val autoOtCoordinator: AutoOtCoordinator? = null,
    /** Shared nav controller — banner taps route through it (D2: nav via the injected
     *  controller, no effect). Nullable so previews/tests stay DI-free; wired in `homeModule`. */
    private val nav: NavigationController? = null,
    /** Runner profile read model (`runners/me`, Dart-fed) — feeds the `decider:earnings`
     *  rate-card-v2 gate ([openDeciderTarget]) and the photo shown in the map's
     *  "you are here" marker (same source as the Profile header). Nullable so
     *  previews/tests stay DI-free (gate degrades to the native PayoutHome, marker
     *  to the Person glyph); wired in `homeModule`. */
    private val profileStore: RunnerProfileStore? = null,
    /** Runner-consent gate (Flutter parity) — drives the home consent sheet. Nullable for previews/tests. */
    private val kavachConsent: KavachConsentGate? = null,
    /** GPS-service gate (ECPO-873, reduced scope). Nullable so previews/tests render
     *  Home ungated; wired in `homeModule`. */
    private val permissionObserver: PermissionObserver? = null,
) : ViewModel() {
    private val _uiState = MutableStateFlow(initialState(initialPhase))
    val uiState: StateFlow<HomeUiState> = _uiState.asStateFlow()
    /**
     * Side-effect channel — snackbars and (future) navigation commands. Buffer
     * 8 covers a burst of rapid emissions without dropping; `extraBufferCapacity`
     * (rather than `replay`) ensures a late re-subscriber doesn't see prior
     * effects. See [HomeUiEffect].
     */
    private val _effects = MutableSharedFlow<HomeUiEffect>(extraBufferCapacity = 8)
    val effects: SharedFlow<HomeUiEffect> = _effects.asSharedFlow()

    /**
     * Latest GPS fix, fed into the cards mapper so the hotspot distance label
     * updates as the runner moves. Owned here (not pulled per-emit from
     * [locationProvider]) because [LocationProvider.trackLocation] is a
     * separate Flow we collect once in [init] — the StateFlow lets us
     * combine it cleanly into the cards projection.
     */
    private val _runnerLocation = MutableStateFlow<SnabbitLocation?>(null)

    /**
     * The same fix, published so the surfaces this screen hosts read THIS stream
     * instead of opening their own. [LocationProvider.trackLocation] hands every
     * collector an independent FusedLocationProvider request, so the AWOL
     * hotspot-distance tracker used to run a second continuous HIGH_ACCURACY
     * stream alongside this one for a single screen; it now consumes this
     * StateFlow (wired in `HomeTabContent`), which replays the latest fix to a
     * late subscriber. Same accuracy and cadence as before — one request, not two.
     *
     * Null = no usable fix (permission denied / GPS off / failure): consumers hide
     * their distance readout rather than render a stale one.
     */
    val runnerLocation: StateFlow<SnabbitLocation?> = _runnerLocation.asStateFlow()

    /** The live `trackLocation` collection. Restarted on grant because the gated
     *  wrapper's stream terminates once on `PermissionDenied`. */
    private var trackingJob: Job? = null

    /** Auto-dismiss timer for the seva helper card. A new [HomeUiIntent.TapSeva]
     *  cancels the running timer so the 5s window restarts each tap. */
    private var sevaHelperDismissJob: Job? = null

    /** Single-flight guard for the Saathi IVR POST — a second tap while the request is in flight is
     *  a no-op (mirrors [sevaHelperDismissJob]). Deliberately NOT the shared [HomeUiState.inFlight]
     *  slot, so a Saathi call never disables the attendance / lunch / logout CTAs. */
    private var saathiCallJob: Job? = null

    /** Centre of the last successful `seva/nearby` fetch. The move-gate
     *  ([maybeRefetchSevaOnMove]) refetches only once the runner leaves its
     *  half-radius, so the GPS stream doesn't spam the endpoint. */
    private var lastSevaFetchCenter: MapCoords? = null

    /** Single-flight guard for `seva/nearby`. Two triggers race on startup — the
     *  [init] `loadAll` fetch and the first location fix ([maybeRefetchSevaOnMove]) —
     *  and [lastSevaFetchCenter] is only assigned after the call returns, so the
     *  first fix sees it still `null` and fires an identical duplicate. Suppressing
     *  a fetch while one is already in flight closes that window (ECPO-904). */
    private var sevaFetchJob: Job? = null

    /** Whether the last projection rendered the Map archetype. Seva markers are only
     *  drawn by the map, so the fetch is fired on the transition *into* Map (and gated
     *  off every HeroLayout state) rather than eagerly on init (ECPO-905). */
    private var wasMapArchetype: Boolean = initialPhase.bg() == HomeBg.Map

    /** Expert-v2 Home/attendance/lunch events (additive to the legacy inline events). */
    private val homeAnalytics = HomeAnalytics(analytics)

    // Cross-cutting transient-error events (X.3) for Home's snackbar failures — built from the same
    // injected tracker (stateless wrapper), so no new constructor dependency.
    private val errorAnalytics = ErrorAnalytics(analytics)

    /** `home_screen_scrolled` fires at most once per Home mount. */
    private var homeScrolledFired = false

    /** Last `home_primary_state`, to fire `home_screen_load` initial + state-change loads. */
    private var lastHomePrimaryState: String? = null

    init {
        // Mirror the backend SOS-visibility flag into ui state. Its own collector (not part of the
        // main projection combine) so it can't perturb the hero pipeline.
        sosVisibility?.let { gate ->
            viewModelScope.launch {
                gate.visible.collect { v -> _uiState.update { it.copy(sosVisible = v) } }
            }
        }
        // Fold the gamification balances into the top-nav pills. Own collector
        // (not part of the hero combine) — counts can't perturb the projection.
        viewModelScope.launch {
            gamification.state.collect { g ->
                _uiState.update { it.copy(coinsCount = g.coinsTotal, redCardsCount = g.redCardsTotal) }
            }
        }
        // Rewards-pill gate — Flutter parity with the HomeRewardsHeaderPill guard
        // (`optedForNewRateCard && runnerStatus != SUSPENDED`). Profile-not-loaded
        // ⇒ closed (Dart's `runnerStatus != null`). Tiering is NOT checked here —
        // when the tier badge resolves it takes the coins slot in HomeTopNav. The
        // red card pill additionally needs the RC kill-switch (default OFF — dark
        // rollout; flipping it off is the rollback path, no release needed).
        profileStore?.let { store ->
            viewModelScope.launch {
                combine(store.state, suspendedReadModel.info) { bridge, suspended ->
                    val profile = (bridge as? ProfileBridgeState.Content)?.profile
                    profile != null && !profile.isRateCardV1 && suspended == null
                }.collect { gate ->
                    _uiState.update {
                        it.copy(
                            rewardsPillsVisible = gate,
                            redCardPillVisible = gate &&
                                remoteConfig.getBool(RC_SHOW_RED_CARD_PILL, false),
                        )
                    }
                }
            }
        }
        // Combine shift + phase + break-phase + GPS so the projection sees them
        // atomically. Without combine, separate `collect` blocks race and the
        // screen briefly renders two lifecycle states at once. The 1s ticker is
        // a fifth source so the active-break countdown re-projects each second;
        // StateFlow de-dups equal states, so non-break ticks don't recompose.
        // Pre-combine the shift envelope with the takeover read models (suspended
        // + see-you-tomorrow) so the main projection stays within the 5-arg typed
        // `combine`. Either takeover, when active, owns the whole hero.
        val shiftWithTakeovers = combine(
            readModel.state,
            suspendedReadModel.info,
            seeYouTomorrowReadModel.active,
        ) { shift, suspended, seeYouTomorrow ->
            HeroEnvelope(shift, suspended, seeYouTomorrow)
        }
        viewModelScope.launch {
            combine(
                shiftWithTakeovers,
                readModel.phase,
                lunchReadModel.phase,
                _runnerLocation,
                secondTicker(),
            ) { hero, phase, lunchPhase, loc, _ ->
                Projection(hero.shift, hero.suspended, hero.seeYouTomorrow, phase, lunchPhase, loc)
            }.collect { p ->
                // `MutableStateFlow.update {}` reads the LATEST value at call time —
                // the projection takes `current` as a parameter rather than reading
                // `_uiState.value` itself. Otherwise a tick that reads value-at-T1
                // and writes the projected result back at T2 silently clobbers any
                // write `launchAction` made in between (e.g. the post-success
                // `inFlight=null, sheet=null` reset), which left End Break "stuck".
                _uiState.update { current ->
                    projectHomeStateFrom(
                        current, p.shift, p.suspended, p.seeYouTomorrow,
                        p.shiftPhase, p.lunchPhase, p.runnerLocation,
                    )
                }
                // Seva markers belong to the Map archetype; fetch when we enter it
                // (and only then — [refreshNearbySeva] no-ops off-map). Re-entry
                // refetches; staying on the map doesn't (movement is [maybeRefetchSevaOnMove]).
                val onMap = _uiState.value.phase.bg() == HomeBg.Map
                if (onMap && !wasMapArchetype) refreshNearbySeva()
                wasMapArchetype = onMap
                val ps = homePrimaryState(_uiState.value)
                when {
                    lastHomePrimaryState == null -> homeAnalytics.screenLoaded(ps, "initial_load")
                    lastHomePrimaryState != ps -> homeAnalytics.screenLoaded(ps, "state_change")
                    else -> Unit
                }
                if (lastHomePrimaryState != ps) {
                    // Only $set spec-dictionary states — keep KMP-only values
                    // (idle / suspended) out of the persistent profile property.
                    if (ps in DICTIONARY_HOME_STATES) homeAnalytics.setCurrentHomeState(ps)
                    if (ps == "no_show_today" && lastHomePrimaryState != null) {
                        homeAnalytics.noShowMarked()
                        homeAnalytics.setLastNoShowAt(currentTimeMs())
                    }
                    lastHomePrimaryState = ps
                }
            }
        }
        observeFirstLoad()
        observeLunchRequestSheet()
        observeBanners()
        // First load, once per retained-VM lifetime. Tab re-entry does NOT
        // re-fetch (see [loadAll]) — only pull-to-refresh does.
        loadAll()
        observeKavachConsent()

        // Profile photo for the map's "you are here" marker — same Dart-fed
        // runners/me read model the Profile header renders from. Content-only:
        // a transient Error push keeps the last good photo instead of blanking it.
        profileStore?.let { store ->
            viewModelScope.launch {
                store.state.collect { bridge ->
                    (bridge as? ProfileBridgeState.Content)?.profile?.photoUrl?.let { url ->
                        _uiState.update { it.copy(profilePhotoUrl = url) }
                    }
                }
            }
        }

        // Seed the map camera from the cached last-known fix so first paint lands
        // on the runner's real location, not the Bangalore fixture — kills the
        // fixture→live-fix jump (each Lite-Mode camera move = a fresh snapshot
        // fetch). No GPS scan, just the OS-cached fix, so it's fast. The live
        // stream below overwrites it the instant a real fix lands; the null guard
        // means we never clobber a fresher fix that already arrived.
        viewModelScope.launch {
            if (_runnerLocation.value == null) {
                (locationProvider.getLastKnownLocation() as? LocationResult.Success)
                    ?.location
                    ?.let { if (_runnerLocation.value == null) _runnerLocation.value = it }
            }
        }

        startLocationTracking()
        observeLocationGate()
    }

    /** Pre-combined takeover envelope — the shift state plus the two full-hero
     *  read models (suspended, see-you-tomorrow) — folded so the main `combine`
     *  stays within its 5-arg typed arity. */
    private data class HeroEnvelope(
        val shift: Shift?,
        val suspended: SuspendedInfo?,
        val seeYouTomorrow: Boolean,
    )

    /**
     * The unified Home projection. A break (LUNCH_*) takes over the Map
     * archetype: the upcoming pill replaces the searching widget, the active
     * break is a body card, and `heroCards` collapse (the LUNCH envelope isn't
     * an attendance widget, so `shift` is already null). Outside a break this is
     * the shift projection, with live GPS distance threaded into the cards.
     * Never touches `sheet` here except to clear a stale lunch sheet once the
     * break ends — attendance sheets pass through.
     */
    private data class Projection(
        val shift: Shift?,
        val suspended: SuspendedInfo?,
        val seeYouTomorrow: Boolean,
        val shiftPhase: ShiftPhase,
        val lunchPhase: LunchPhase?,
        val runnerLocation: SnabbitLocation?,
    )

    private fun projectHomeStateFrom(
        current: HomeUiState,
        shift: Shift?,
        suspended: SuspendedInfo?,
        seeYouTomorrow: Boolean,
        shiftPhase: ShiftPhase,
        lunchPhase: LunchPhase?,
        runnerLocation: SnabbitLocation?,
    ): HomeUiState {
        // Suspended is a full hero takeover (Dart `RUNNER_SUSPENDED`) — it
        // outranks attendance, the map, lunch, and any open sheet. The
        // submit-lock ([suspendRequestSubmitted]) is user-action state, so it
        // rides through `current.copy` untouched.
        if (suspended != null) {
            return current.copy(
                phase = ShiftPhase.PreShift,
                heroCards = listOf(HomeCard.Suspended(isAadhaarRekyc = suspended.isAadhaarRekyc)),
                bodyCards = emptyList(),
                mapWidget = null,
                sheet = null,
            )
        }
        // See-you-tomorrow is the post-logout hero takeover (Dart
        // `RUNNER_SEE_YOU_TOMORROW`) — same full-hero treatment as suspended,
        // ranked just below it (a suspended runner never sees it).
        if (seeYouTomorrow) {
            return current.copy(
                phase = ShiftPhase.PreShift,
                heroCards = listOf(HomeCard.SeeYouTomorrow),
                bodyCards = emptyList(),
                mapWidget = null,
                sheet = null,
            )
        }
        // "You are here" follows the live GPS fix; retain the last centre on a
        // transient null so the map doesn't snap back to the default fixture.
        val nextCenter = runnerLocation
            ?.let { MapCoords(it.latitude, it.longitude) }
            ?: current.mapCenter
        if (lunchPhase != null) {
            val nowMs = currentTimeMs()
            return current.copy(
                // Force the Map archetype (HomeBg.Map) — the mockup shows the
                // break card over the map background, chrome + nav intact.
                phase = ShiftPhase.SearchingForJobs,
                heroCards = emptyList(),
                bodyCards = lunchBodyCards(lunchPhase, nowMs),
                mapWidget = lunchMapWidget(lunchPhase, nowMs),
                mapCenter = nextCenter,
            )
        }
        val hero = attendanceCardsFrom(shift, runnerLocation, nowMs = currentTimeMs()).let { cards ->
            // The hotspot nav card (ShiftLogin) only makes sense pre-shift
            // (LOGIN_HOTSPOT). In the Map archetype the hotspot info is already
            // shown by the bg map + floating widget — the nav card is a dupe.
            if (shiftPhase == ShiftPhase.SearchingForJobs) {
                cards.filterNot { it is HomeCard.ShiftLogin }
            } else cards
        }
        return current.copy(
            phase = shiftPhase,
            heroCards = hero,
            bodyCards = emptyList(),
            mapWidget = when (shiftPhase) {
                // ECPO-819: from shift end − 30 min the wait envelope flags a
                // logout reminder — show the Logout pill with the CTA disabled
                // (logout opens up only at shift end, via RUNNER_LOGOUT).
                ShiftPhase.SearchingForJobs ->
                    shift?.shiftEndLabel?.takeIf { shift.showLogoutReminder }
                        ?.let { MapFloatingState.Logout(shiftEndLabel = it, ctaEnabled = false) }
                        ?: MapFloatingState.SearchingForJobs
                ShiftPhase.Logout -> MapFloatingState.Logout(
                    shiftEndLabel = shift?.shiftEndLabel.orEmpty(),
                )
                else -> null
            },
            // The break ended — close any lingering lunch sheet. Attendance /
            // other sheets are preserved.
            sheet = current.sheet?.takeUnless {
                it is HomeSheet.LunchRequest || it is HomeSheet.EndBreakConfirm
            },
            mapCenter = nextCenter,
        )
    }

    /**
     * Clear the first-load shimmer once real data arrives. Waits for the read
     * model's first `current_state` envelope, or gives up after
     * [FIRST_LOAD_TIMEOUT] so a stuck bridge (Dart never pushes / no shift)
     * doesn't shimmer forever — either way the runner sees the resolved
     * (possibly empty) screen. If the store was already populated when Home
     * mounted, `initialState` seeds `isLoading = false` and this returns
     * immediately, so there's no shimmer flash.
     */
    private fun observeFirstLoad() {
        viewModelScope.launch {
            withTimeoutOrNull(FIRST_LOAD_TIMEOUT) { readModel.hasLoaded.first { it } }
            _uiState.update { it.copy(isLoading = false) }
        }
    }

    /** Best-effort primary-panel state for `home_screen_load`, derived from the
     *  resolved projection (there is no single mode field — LLD §4.3). */
    private fun homePrimaryState(s: HomeUiState): String = when {
        s.heroCards.any { it is HomeCard.Suspended } -> "suspended"
        s.bodyCards.any { it is HomeCard.Lunch } -> "lunch_break"
        s.phase == ShiftPhase.Logout -> "shift_ending"
        s.heroCards.any { it is HomeCard.ShiftLogin } -> "login_window_open"
        s.phase == ShiftPhase.SearchingForJobs -> "idle_state_map"
        s.heroCards.any { it is HomeCard.Attendance.TodayStatus && it.status == AttendanceStatus.NoShow } -> "no_show_today"
        s.heroCards.any { it is HomeCard.Attendance.TodayStatus } -> "present_prelogin"
        s.heroCards.any { it is HomeCard.Attendance.TomorrowProvisional } -> "provisional_attendance"
        else -> "idle"
    }

    /** Upcoming-break pill (Request/Cooldown); null while the break is active. */
    private fun lunchMapWidget(phase: LunchPhase, nowMs: Long): MapFloatingState? = when (phase) {
        LunchPhase.Request -> MapFloatingState.LunchRequest
        is LunchPhase.Cooldown -> MapFloatingState.Lunch(
            remainingSeconds = secondsUntil(phase.cooldownEndMs, nowMs).coerceAtLeast(0),
        )
        is LunchPhase.OnBreak -> null
    }

    /** Active-break body card (the TIME LEFT card); empty otherwise. */
    private fun lunchBodyCards(phase: LunchPhase, nowMs: Long): List<HomeCard> =
        when (phase) {
            is LunchPhase.OnBreak -> {
                val startingSoon = nowMs < phase.cooldownEndMs
                val card = if (startingSoon) {
                    // Pre-start sub-window: count down to when the break itself
                    // starts, not to when it ends — a genuine second countdown,
                    // not a relabeled cross-section of the break-only clock.
                    val remaining = secondsUntil(phase.cooldownEndMs, nowMs).coerceAtLeast(0)
                    val total = phase.cooldownStartMs
                        ?.let { secondsUntil(phase.cooldownEndMs, it) }
                        ?: remaining
                    HomeCard.Lunch(
                        remainingSeconds = remaining,
                        totalSeconds = total,
                        colorState = BreakColorState.Initial,
                        isStartingSoon = true,
                    )
                } else {
                    val remaining = secondsUntil(phase.breakEndMs, nowMs).coerceAtLeast(0)
                    HomeCard.Lunch(
                        remainingSeconds = remaining,
                        totalSeconds = phase.breakTotalSec,
                        colorState = breakColorFor(remaining, phase.breakTotalSec),
                        isStartingSoon = false,
                    )
                }
                listOf(card)
            }
            else -> emptyList()
        }

    /** Remaining-fraction → ring band: <30% red, <50% amber, else green. */
    private fun breakColorFor(remaining: Int, totalSeconds: Int): BreakColorState {
        if (totalSeconds <= 0) return BreakColorState.Green
        val fraction = remaining.toFloat() / totalSeconds
        return when {
            fraction < RED_THRESHOLD -> BreakColorState.Red
            fraction < AMBER_THRESHOLD -> BreakColorState.Amber
            else -> BreakColorState.Green
        }
    }

    private fun secondsUntil(targetMs: Long, nowMs: Long): Int = ((targetMs - nowMs) / 1000L).toInt()

    /** Emits immediately (so `combine` fires before the first tick) then every second. */
    private fun secondTicker() = flow {
        while (true) {
            emit(Unit)
            delay(1.seconds)
        }
    }

    /**
     * Auto-open the break-offer sheet on the LUNCH_REQUEST edge and close it
     * when the phase leaves Request (mirrors how PA_BEFORE_LOGOUT auto-mounts
     * its sheet). Edge-triggered via `distinctUntilChanged`, so a deny tap (which
     * closes the sheet) is not re-opened by a follow-up tick before the envelope
     * flips.
     */
    private fun observeLunchRequestSheet() {
        viewModelScope.launch {
            lunchReadModel.phase
                .map { it is LunchPhase.Request }
                .distinctUntilChanged()
                .collect { isRequest ->
                    if (isRequest) {
                        homeAnalytics.lunchUpcomingNudge("home")
                        _uiState.value = _uiState.value.copy(sheet = HomeSheet.LunchRequest)
                    } else if (_uiState.value.sheet is HomeSheet.LunchRequest) {
                        _uiState.value = _uiState.value.copy(sheet = null)
                    }
                }
        }
    }

    // WS5: the break-end warm-up refresh was removed — the post-break state is
    // pushed over MQTT when the break actually ends (DB source of truth), so the
    // anticipatory current_state re-poll is redundant.

    /** Current coords for break/end, or null on any non-success fix (send
     *  without coords — Flutter parity; never blocks the action). */
    private suspend fun currentCoords(): Pair<Double?, Double?> {
        val loc = (locationProvider.getCurrentOrLastKnown() as? LocationResult.Success)?.location
            ?: return null to null
        return loc.latitude to loc.longitude
    }

    fun onIntent(intent: HomeUiIntent) {
        when (intent) {
            HomeUiIntent.Load -> loadAll()
            HomeUiIntent.HomeScrolled -> onHomeScrolled()
            HomeUiIntent.TapCoins -> {
                homeAnalytics.topBarCta("coins")
                openCoinsPage()
            }
            HomeUiIntent.TapRedCards -> {
                homeAnalytics.topBarCta("red_cards")
                openRedCardsPage()
            }
            // SOS from the home top-nav pill → raise a manual, job-independent SOS (contract §3). The
            // app-scoped AppSosHost (shell) renders the alert + navigates. Non-blocking + best-effort.
            HomeUiIntent.TapSos -> {
                homeAnalytics.topBarCta("sos")
                sosCoordinator?.let { c ->
                    viewModelScope.launch {
                        try {
                            c.raiseManual()
                        } catch (e: CancellationException) {
                            throw e
                        } catch (e: Throwable) {
                            // best-effort — the coordinator manages SOS state/telemetry itself
                        }
                    }
                }
            }
            // Saathi support call — IVR-first with a dialer fallback (see [handleTapSaathi]).
            // Saathi shows only outside the job lifecycle (during a job the Job header shows Help).
            HomeUiIntent.TapSaathi -> handleTapSaathi()
            HomeUiIntent.SaathiCallFeedbackShown ->
                _uiState.update { it.copy(saathiCallFeedback = null) }
            HomeUiIntent.TapBell -> Unit
            is HomeUiIntent.TapBanner -> handleTapBanner(intent.id)
            // Card body and Map chip both open directions but stay separate
            // branches so each can fire its own analytics event later.
            is HomeUiIntent.TapHotspot -> {
                homeAnalytics.cta("navigate_hotspot")
                openHotspotDirections(intent.lat, intent.lng)
            }
            is HomeUiIntent.TapHotspotMap -> {
                homeAnalytics.cta("navigate_hotspot")
                openHotspotDirections(intent.lat, intent.lng)
            }
            is HomeUiIntent.TapSeva -> {
                homeAnalytics.cta("seva_pin_tap")
                showSevaHelper(intent.sevaId)
            }
            HomeUiIntent.DismissSevaHelper -> hideSevaHelper()
            is HomeUiIntent.NavigateSeva -> {
                homeAnalytics.cta("seva_navigate")
                _effects.tryEmit(HomeUiEffect.OpenDirections(intent.lat, intent.lng))
            }
            HomeUiIntent.TapLogin -> {
                homeAnalytics.cta("login")
                _effects.tryEmit(HomeUiEffect.NavigateToShiftLogin)
            }
            HomeUiIntent.TapLogout -> {
                homeAnalytics.cta("logout")
                handleTapLogout()
            }
            HomeUiIntent.TapAbsentTomorrow -> openEarningLossSheet()
            HomeUiIntent.TapChangeAttendance -> openChangeAttendanceSheet()
            is HomeUiIntent.ConfirmMarkProvisional -> {
                // Spec: home-panel inline marking fires `home_screen_cta_click`;
                // `mark_attendance_bs_*` is the post-logout / auto-logout sheet only.
                if (_uiState.value.pendingLogoutAfterAttendance) {
                    homeAnalytics.markAttendance(present = intent.present, markingContext = "post_logout")
                } else {
                    homeAnalytics.cta(if (intent.present) "mark_present" else "mark_absent")
                }
                homeAnalytics.setNextShiftAttendance(intent.present)
                launchAction(
                    intent,
                    onSuccess = { outcome ->
                        outcome?.let { postActionCoordinator.show(it) }
                        // START_OT probe after a successful attendance mark (Flutter onAttendanceMarked).
                        autoOtCoordinator?.onAttendanceMarked()
                    },
                ) { attendanceRepository.markProvisional(intent.present) }
            }
            is HomeUiIntent.ConfirmChangeAttendance ->
                handleConfirmChange(intent)
            HomeUiIntent.AcknowledgeWaiver -> {
                homeAnalytics.redCardWaiverAck()
                dismissSheet()
            }
            is HomeUiIntent.ShowRedCardsWaived -> {
                homeAnalytics.redCardWaiverShown(intent.redCardCount)
                _uiState.value = _uiState.value.copy(
                    sheet = HomeSheet.RedCardsWaived(redCardCount = intent.redCardCount),
                )
            }
            HomeUiIntent.DismissSheet -> dismissSheet()
            HomeUiIntent.ConfirmKavachConsent -> {
                // Non-dismissable sheet: guard re-entry, spin the CTA, and surface a transient error on
                // failure while keeping the sheet up to retry. Success closes it (profile refresh flips
                // runnerConsentGiven → won't re-trigger).
                val gate = kavachConsent
                if (gate != null && _uiState.value.inFlight == null) {
                    _uiState.update { it.copy(inFlight = HomeUiIntent.ConfirmKavachConsent) }
                    viewModelScope.launch {
                        val runnerId = profileStore?.snapshot()?.expertId
                        analytics.track("expert_shield_consent_cta", mapOf("runner_id" to runnerId))
                        val ok = gate.submit()
                        if (ok) analytics.track("expert_shield_consent_success", mapOf("runner_id" to runnerId))
                        else analytics.track("expert_shield_consent_error", mapOf("runner_id" to runnerId, "error" to "api_failure"))
                        _uiState.update { it.copy(inFlight = null, sheet = if (ok) null else it.sheet) }
                        if (!ok) _effects.tryEmit(HomeUiEffect.ShowSnackbar(RunnerActionError.Unknown()))
                    }
                }
            }
            HomeUiIntent.OpenLunchRequestSheet ->
                _uiState.update { it.copy(sheet = HomeSheet.LunchRequest) }
            HomeUiIntent.AcceptLunch -> launchAction(intent) { lunchRepository.acceptLunch() }
            HomeUiIntent.DenyLunch -> launchAction(intent) { lunchRepository.denyLunch() }
            HomeUiIntent.RequestEndBreak -> {
                homeAnalytics.cta("end_break")
                _uiState.value = _uiState.value.copy(sheet = HomeSheet.EndBreakConfirm)
            }
            HomeUiIntent.ConfirmEndBreak -> {
                analytics.track(BREAK_CONFIRM_END_EVENT)
                homeAnalytics.endBreakConfirm()
                launchAction(intent) {
                    val (lat, lng) = currentCoords()
                    lunchRepository.endBreak(lat, lng)
                }
            }
            HomeUiIntent.RequestComeBack -> {
                homeAnalytics.cta("end_leave")
                requestComeBack()
            }
            HomeUiIntent.UpdateAadhaar -> _effects.tryEmit(HomeUiEffect.NavigateToAadhaarReKyc)
            HomeUiIntent.TapGoToEarnings -> _effects.tryEmit(
                HomeUiEffect.NavigateToEarnings(
                    // Dart parity: `user.isRateCardV2Effective` picks webview vs Payout Home.
                    // Suspended reads the flag off its projector; see-you-tomorrow has
                    // no projector flag, so fall back to the live profile snapshot.
                    rateCardV2Effective = suspendedReadModel.info.value?.isRateCardV2Effective == true ||
                        profileStore?.snapshot()?.isRateCardV2Effective == true,
                ),
            )
            // "Refer and Earn" on the see-you-tomorrow card → the shared refer
            // decider (same destination as the Refer banner / Profile tile), but
            // attributed to this surface for the referrals-v2 webview.
            HomeUiIntent.TapReferAndEarn ->
                openDeciderTarget(DECIDER_REFER, SEE_YOU_TOMORROW_REFER_ENTRY_POINT)
            HomeUiIntent.EnableLocation -> enableLocation()
        }
    }

    /**
     * Fire the reactivation request for a suspended runner — the CMP port of
     * Dart `RunnerSuspended._onComeBackToWorkTapped`. Single-flight + submit
     * lock: a second tap while pending, or after the request already resolved,
     * is a no-op.
     *  - [UnsuspendResult.Reactivated] (200/409): lock the CTA + ask the read
     *    model to refresh so the next `current_state` envelope flips the hero
     *    off the suspended card.
     *  - [UnsuspendResult.Denied] (400): lock the CTA too — the runner has been
     *    told; no snackbar.
     *  - [UnsuspendResult.Failed]: leave the CTA tappable + surface a snackbar.
     * Analytics mirror Dart's `expert_wants_to_join_back` action buckets.
     */
    private fun requestComeBack() {
        if (_uiState.value.inFlight != null || _uiState.value.suspendRequestSubmitted) return
        _uiState.value = _uiState.value.copy(inFlight = HomeUiIntent.RequestComeBack)
        viewModelScope.launch {
            when (val result = suspendedRepository.unsuspend()) {
                is UnsuspendResult.Reactivated -> {
                    analytics.track(
                        EXPERT_WANTS_TO_JOIN_BACK,
                        mapOf("action" to "success", "status_code" to result.statusCode.toString()),
                    )
                    _uiState.value = _uiState.value.copy(inFlight = null, suspendRequestSubmitted = true)
                    suspendedReadModel.requestRefresh()
                }
                is UnsuspendResult.Denied -> {
                    analytics.track(
                        EXPERT_WANTS_TO_JOIN_BACK,
                        mapOf(
                            "action" to "denied",
                            "status_code" to "400",
                            "reason" to result.reason,
                            "message" to result.message,
                        ),
                    )
                    _uiState.value = _uiState.value.copy(inFlight = null, suspendRequestSubmitted = true)
                }
                is UnsuspendResult.Failed -> {
                    analytics.track(
                        EXPERT_WANTS_TO_JOIN_BACK,
                        mapOf(
                            "action" to "failed",
                            "status_code" to (result.statusCode?.toString() ?: "null"),
                            "error" to "request_failed",
                        ),
                    )
                    _uiState.value = _uiState.value.copy(inFlight = null)
                    // Dart parity: show the server body message when the endpoint sends
                    // one, else fall back to the typed-error copy (errorFor → Unknown).
                    _effects.tryEmit(
                        HomeUiEffect.ShowSnackbar(
                            error = RunnerActionError.Unknown(result.statusCode),
                            message = result.message,
                        ),
                    )
                    // Transient snackbar error → error_screen_load (X.3). `Failed` collapses transport +
                    // non-classified statuses into Unknown(statusCode), so no connectivity signal survives.
                    errorAnalytics.errorScreenLoad(
                        errorType = "unsuspend_failed",
                        errorFormat = "snackbar",
                        errorContext = "home",
                        isNetworkError = false,
                        retryAvailable = false,
                        contactSupportAvailable = false,
                    )
                }
            }
        }
    }

    /** Open external maps in directions mode to the hotspot. Shared by both the
     *  card-body and Map-chip taps; null coords no-op (nothing to navigate to). */
    private fun openHotspotDirections(lat: Double?, lng: Double?) {
        if (lat != null && lng != null) {
            _effects.tryEmit(HomeUiEffect.OpenDirections(lat, lng))
        }
    }

    /** Continuous GPS stream feeding [_runnerLocation]. Extracted so the gate can
     *  restart it on grant — the gated `trackLocation` wrapper completes the flow on
     *  `PermissionDenied`, so a grant after a denied cold start needs a fresh collect. */
    private fun startLocationTracking() {
        trackingJob?.cancel()
        trackingJob = viewModelScope.launch {
            try {
                locationProvider.trackLocation().collectLatest { result ->
                    val fix = (result as? LocationResult.Success)?.location
                    _runnerLocation.value = fix
                    if (fix != null) maybeRefetchSevaOnMove(fix)
                }
            } catch (e: CancellationException) {
                throw e
            } catch (t: Throwable) {
                logger.e(TAG, "location stream failed; distance disabled", t)
            }
        }
    }

    /**
     * GPS-service gate (ECPO-873, reduced scope). The Dart startup flow owns
     * location permission/background/precise before Home mounts; this only reacts
     * to the GPS toggle flipping off *while on Home* (which Dart's resume-only
     * re-check can't catch). observeService(GPS) fires live on PROVIDERS_CHANGED.
     * No-op unless the observer is wired (previews/tests render ungated).
     */
    private fun observeLocationGate() {
        val observer = permissionObserver ?: return
        viewModelScope.launch {
            observer.observeService(ServiceType.GPS).collect { gpsOn ->
                val wasOff = _uiState.value.locationServiceOff
                _uiState.update { it.copy(locationServiceOff = !gpsOn) }
                // GPS just came back on → re-seed camera, refetch seva, restart the
                // stream (the gated trackLocation completed while GPS/permission was unavailable).
                if (wasOff && gpsOn) onLocationEnabled()
            }
        }
    }

    private fun onLocationEnabled() {
        viewModelScope.launch {
            (locationProvider.getLastKnownLocation() as? LocationResult.Success)
                ?.location
                ?.let { _runnerLocation.value = it }
        }
        refreshNearbySeva()
        startLocationTracking()
    }

    /** "Turn on GPS" tap → trigger the system location-resolution dialog. Permission
     *  is already granted (Dart startup flow), so getCurrentLocation reaches the
     *  platform provider and shows the enable-GPS dialog; observeService(GPS) then
     *  re-derives on PROVIDERS_CHANGED. */
    private fun enableLocation() {
        viewModelScope.launch { locationProvider.getCurrentLocation() }
    }

    /**
     * The full Home fetch fan-out. Fired ONCE from [init] (the VM is retained
     * for the shell's whole lifetime, so this is the real first load) and on
     * explicit pull-to-refresh / retry via [HomeUiIntent.Load]. Deliberately
     * NOT tied to tab (re)entry: MQTT already pushes fresh current_state on
     * change, the disconnected fallback poll covers the rest, and the
     * "catch up after backgrounding" case is handled by Dart's
     * didChangeAppLifecycleState(resumed). Switching tabs never backgrounds the
     * process, so nothing goes stale — re-fetching there is pure overhead.
     */
    private fun loadAll() {
        readModel.requestRefresh()
        refreshNearbySeva()
        refreshBanners()
        // Keep the runner profile (runners/me) fresh so the suspended-card
        // variant flags are current — Dart refreshes it via runnersMeSetup
        // around these lifecycle points too.
        viewModelScope.launch { suspendedReadModel.requestProfileRefresh() }
    }

    /**
     * Fetch nearby Seva facilities for the current fix and hold them in state
     * for the map to plot. Best-effort: no fix → no fetch; any error → markers
     * stay as they were (silent, like [refreshLifecycleAvailability]). Gated to the
     * Map archetype (ECPO-905) and single-flighted (ECPO-904); fired on entering the
     * map, on qualifying movement ([maybeRefetchSevaOnMove]) and on pull-to-refresh.
     */
    private fun refreshNearbySeva() {
        // Only the Map archetype renders seva markers; on every HeroLayout state the
        // result is fetched and discarded, so skip it (and the GPS read) — ECPO-905.
        if (_uiState.value.phase.bg() != HomeBg.Map) return
        // Single-flight: a fetch already in flight covers this trigger — see [sevaFetchJob].
        if (sevaFetchJob?.isActive == true) return
        sevaFetchJob = viewModelScope.launch {
            try {
                val (lat, lng) = currentCoords()
                if (lat == null || lng == null) return@launch
                val points = (sevaRepository.nearby(lat, lng, radius = SEVA_FETCH_RADIUS_M) as? Result.Ok)
                    ?.value ?: return@launch
                lastSevaFetchCenter = MapCoords(lat, lng)
                _uiState.value = _uiState.value.copy(sevaPoints = points)
            } catch (e: CancellationException) {
                throw e
            } catch (t: Throwable) {
                // Markers are decoration, home keeps working — breadcrumb only.
                logger.e(TAG, "nearby-seva fetch failed; markers unchanged", t)
            }
        }
    }

    /**
     * Fetch the BE-driven "More From Snabbit" banner list. First load shows a
     * shimmer ([HomeUiState.bannersLoading], seeded true); once the fetch
     * resolves the section must never go blank — a non-empty valid list
     * replaces what's showing, while `Err`/`Ok(empty)` fall back to
     * [REFER_FALLBACK] on first load and keep the last good list on a later
     * refresh. Banners are decoration, so failures are breadcrumbs, never
     * snackbars — same policy as [refreshNearbySeva]. Called on init and on
     * [HomeUiIntent.Load].
     *
     * Only asks; [observeBanners] renders the result, so a fetch started
     * anywhere else in the shell updates Home the same way.
     */
    private fun refreshBanners() {
        viewModelScope.launch {
            try {
                homeBannersStore.refresh()
            } catch (e: CancellationException) {
                throw e
            } catch (t: Throwable) {
                logger.e(TAG, "home-banners fetch failed", t)
                settleBannersWithFallback()
            }
        }
    }

    /**
     * Render whatever the store last resolved, whoever fetched it. Home and the
     * Updates badge read one [HomeBannersStore] state, so a refresh triggered
     * from the shell lands here too instead of leaving the carousel on data the
     * store has already replaced.
     *
     * Keyed on the banner slice alone — a badge-only change must not re-run the
     * fallback or re-log the same failure.
     */
    private fun observeBanners() {
        viewModelScope.launch {
            homeBannersStore.state
                .map { it.banners }
                .distinctUntilChanged()
                .collect { result ->
                    when (result) {
                        // Nothing has resolved yet — hold the shimmer.
                        null -> Unit
                        is Result.Ok ->
                            if (result.value.isNotEmpty()) {
                                _uiState.update {
                                    it.copy(moreFromSnabbit = result.value, bannersLoading = false)
                                }
                            } else {
                                settleBannersWithFallback()
                            }
                        is Result.Err -> {
                            logger.e(TAG, "home-banners fetch failed: ${result.error}")
                            settleBannersWithFallback()
                        }
                    }
                }
        }
    }

    /** End the banner shimmer without BE content: first load (list still empty)
     *  → the Refer fallback; a later failed refresh keeps the last good list. */
    private fun settleBannersWithFallback() {
        _uiState.update {
            it.copy(
                moreFromSnabbit = it.moreFromSnabbit.ifEmpty { listOf(REFER_FALLBACK) },
                bannersLoading = false,
            )
        }
    }

    /**
     * Resolve a banner tap to its destination (LLD §8.2):
     *  - `decider:<key>` → client-resolved at tap time ([openDeciderTarget])
     *  - `/route` → Flutter route via the keep-host hop (Home stays alive
     *    behind it — same shape as the Coins pill in `homeModule`)
     *  - blank / unknown (incl. the reserved `cmp:` scheme until a CMP banner
     *    destination exists) → no-op + breadcrumb (a newer BE path on an older
     *    app must never crash — forward compatibility)
     * Stale id (tap raced a refresh) is a plain no-op.
     */
    private fun handleTapBanner(id: String) {
        val banner = _uiState.value.moreFromSnabbit.firstOrNull { it.id == id } ?: return
        analytics.track(
            BANNER_CLICK_EVENT,
            mapOf("banner_id" to banner.id, "click_path" to banner.clickPath),
        )
        homeAnalytics.bannerCta(bannerId = banner.id, clickPath = banner.clickPath)
        // The client-side Refer fallback opens whatever the Profile tile /
        // Refer tab open — routed through the shared decider so all refer
        // entry points stay in lockstep.
        if (banner.id == REFER_FALLBACK.id) {
            openDeciderTarget(DECIDER_REFER)
            return
        }
        val path = banner.clickPath
        when {
            // `decider:<key>` — BE delegates the destination to the client's
            // live gating (RC flags / runner profile), resolved AT TAP TIME via
            // ProfileRouteDecider. For targets whose page depends on runner
            // state that can flip after the banner fetch (referrals v2,
            // rate-card v2), this beats a static path.
            path.startsWith(DECIDER_PATH_PREFIX) -> {
                val key = path.removePrefix(DECIDER_PATH_PREFIX)
                if (!openDeciderTarget(key)) logger.e(TAG, "unknown decider banner path: $path")
            }
            path.startsWith("/") -> nav?.requestFlutterRouteKeepingHost(
                route = path,
                args = banner.clickArgs,
                recreateKey = "bottom_nav_shell",
                recreateArgs = mapOf("initialTab" to "Home"),
            )
            else -> logger.e(TAG, "unknown banner clickPath: '$path'")
        }
    }

    /**
     * Saathi support call — IVR-first with a dialer fallback, mirroring Flutter
     * `CallUtils.handleCallInitiation` (the same path the app-webview "Call Saathi" bridge hits):
     *  - blank number → graceful "unavailable" feedback, never a POST (Flutter's blank guard);
     *  - else request the masked call — the app's single IVR endpoint,
     *    `POST api/v1/runners/phone_call/{number}`, via the shared [callingDataSource];
     *  - 2xx → success feedback and open NO dialer (the backend rings the runner's phone);
     *  - non-2xx / transport error → fall back to the device dialer.
     * The RC number ([RC_SAATHI_HELPLINE], default [DEFAULT_SAATHI_NUMBER]) is the same number the
     * webview "Call Saathi" uses. Analytics fire on every tap. Single-flight via [saathiCallJob] so a
     * double-tap places exactly one call.
     *
     * Gated by [RC_SAATHI_TICKETING] (default OFF): when the flag is on the tap instead opens
     * the `v1/support` webview via [openSaathiSupportPage] and no call is placed. Analytics
     * fire on both paths, so the tap funnel stays comparable across the rollout.
     */
    private fun handleTapSaathi() {
        analytics.track(SAATHI_TAP_EVENT)
        homeAnalytics.topBarCta("saathi")
        if (remoteConfig.getBool(RC_SAATHI_TICKETING, false)) {
            openSaathiSupportPage()
            return
        }
        val number = remoteConfig.getString(RC_SAATHI_HELPLINE, DEFAULT_SAATHI_NUMBER).trim()
        if (number.isEmpty()) {
            _uiState.update { it.copy(saathiCallFeedback = SaathiCallFeedback.NumberUnavailable) }
            return
        }
        if (saathiCallJob?.isActive == true) return
        saathiCallJob = viewModelScope.launch {
            val placed = try {
                callingDataSource.initiateCall(number)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Throwable) {
                false
            }
            if (placed) {
                _uiState.update { it.copy(saathiCallFeedback = SaathiCallFeedback.CallInitiated) }
            } else {
                customerContactLauncher.dial(number)
            }
        }
    }

    /**
     * Resolve a `decider:` banner key through [ProfileRouteDecider] with the
     * runner's LIVE state (RC flags, `runners/me` profile) and open the result
     * via the keep-host hop. Returns false for an unknown key (caller logs).
     */
    private fun openDeciderTarget(
        key: String,
        referEntryPoint: String = BANNER_REFER_ENTRY_POINT,
    ): Boolean {
        val target = when (key) {
            DECIDER_REFER -> ProfileRouteDecider.referAndEarn(
                referralsV2Enabled = remoteConfig.getBool(ProfileRouteDecider.RC_REFERRALS_V2, false),
                entryPoint = referEntryPoint,
            )
            DECIDER_EARNINGS -> ProfileRouteDecider.monthlyEarnings(
                isRateCardV2Effective = profileStore?.snapshot()?.isRateCardV2Effective == true,
            )
            else -> return false
        }
        nav?.requestFlutterRouteKeepingHost(
            route = target.route,
            args = target.args,
            recreateKey = "bottom_nav_shell",
            recreateArgs = mapOf("initialTab" to "Home"),
        )
        return true
    }

    /**
     * Refetch nearby Seva only after the runner has moved at least half the seva
     * fetch radius ([SEVA_REFETCH_MOVE_M]) from the last fetch centre — so the
     * continuous GPS stream doesn't hit `seva/nearby` on every fix, while the 500 m
     * coverage never develops a gap under the runner. First fix (no centre yet)
     * always fetches. The call + state update stay in [refreshNearbySeva].
     */
    private fun maybeRefetchSevaOnMove(fix: SnabbitLocation) {
        val last = lastSevaFetchCenter
        if (last != null &&
            distanceMeters(last.latitude, last.longitude, fix.latitude, fix.longitude) < SEVA_REFETCH_MOVE_M
        ) {
            return
        }
        refreshNearbySeva()
    }

    /** Look the tapped marker up in [HomeUiState.sevaPoints] and surface its
     *  detail card. Unknown id (stale marker) is a no-op. */
    private fun showSevaHelper(sevaId: String) {
        val point = _uiState.value.sevaPoints.firstOrNull { it.id == sevaId } ?: return
        sevaHelperDismissJob?.cancel()
        _uiState.value = _uiState.value.copy(
            sevaAnnouncement = MapFloatingState.Seva(
                id = point.id,
                customerName = point.name,
                tagLabel = SEVA_TAG_LABEL,
                address = point.road,
                distanceLabel = "${point.distanceMeters} meters away",
                lat = point.lat,
                lng = point.lng,
            ),
        )
        sevaHelperDismissJob = viewModelScope.launch {
            delay(SEVA_HELPER_AUTO_DISMISS_MS)
            _uiState.value = _uiState.value.copy(sevaAnnouncement = null)
        }
    }

    private fun hideSevaHelper() {
        sevaHelperDismissJob?.cancel()
        _uiState.value = _uiState.value.copy(sevaAnnouncement = null)
    }

    /** Fire `home_screen_scrolled` once when the page scrolls to the banner strip. */
    private fun onHomeScrolled() {
        if (homeScrolledFired) return
        homeScrolledFired = true
        val banners = _uiState.value.moreFromSnabbit
        homeAnalytics.homeScrolled(
            bannerCount = banners.size,
            bannerIds = banners.map { it.id },
            firstBannerId = banners.firstOrNull()?.id,
        )
    }

    private fun openEarningLossSheet() {
        // Pick the tomorrow card explicitly — heroCards can lead with a
        // TodayStatus card (e.g. the absent-today envelope emits
        // [TodayStatus, TomorrowProvisional]), so `firstOrNull()` would grab
        // the wrong card and drop the earning-loss amount.
        val amount = (_uiState.value.heroCards.firstOrNull {
            it is HomeCard.Attendance.TomorrowProvisional
        } as? HomeCard.Attendance.TomorrowProvisional)
            ?.day?.potentialEarnLabel
        _uiState.value = _uiState.value.copy(sheet = HomeSheet.EarningLoss(amount = amount))
        homeAnalytics.absentConfirmationShown()
    }

    /**
     * Routes the Change tap to the correct sheet, mirroring Flutter's
     * per-widget-state entry points:
     *  - Present with an active FALSE_ATTENDANCE sheet warning (the
     *    `RUNNER_LOGIN_HOTSPOT` flow) → ChangeAttendanceConfirm, whose penalty
     *    chrome (red-card cluster + CTA badges) is filled by `HomeTabContent`
     *    from the same warning (Dart `job_login.dart:317-334` →
     *    `AttendanceChangeSheet`).
     *  - Present with no such warning (`RUNNER_ATTENDANCE_CONFIRMED`) →
     *    EarningLoss in ChangeToday mode (Dart `attendance_confirmed.dart:212`
     *    → `EarningLossBottomSheet`).
     *  - Absent/NoShow today → ChangeAttendanceConfirm (Dart
     *    `attendance_absent.dart:188`). Penalty chrome, when present, again
     *    rides from the host's sheet-warning projection.
     *
     * The FALSE_ATTENDANCE warning is the same signal Flutter keys on, read
     * live from [gamification]; `ShiftPhase` can't disambiguate the two Present
     * flows (both are `PreShift`).
     */
    private fun openChangeAttendanceSheet() {
        val todayCard = _uiState.value.heroCards.firstOrNull {
            it is HomeCard.Attendance.TodayStatus
        } as? HomeCard.Attendance.TodayStatus
        val isProvisional = todayCard?.isProvisional == true
        // FALSE_ATTENDANCE is a today-only penalty (Dart shows it on the login /
        // live-shift surfaces, never on the provisional/tomorrow change). For a
        // provisional shift, ignore the warning so a Present change routes to the
        // plain EarningLoss sheet instead of the red-card penalty sheet.
        val hasFalseAttendanceWarning = !isProvisional &&
            gamification.state.value.sheetWarnings
                .filterForLifecycle(LifecycleActionTypes.FALSE_ATTENDANCE)
                .isNotEmpty()
        _uiState.value = _uiState.value.copy(
            sheet = if (todayCard?.status == AttendanceStatus.Present && !hasFalseAttendanceWarning) {
                HomeSheet.EarningLoss(
                    amount = todayCard.day?.potentialEarnLabel,
                    mode = HomeSheet.EarningLoss.Mode.ChangeToday,
                )
            } else {
                HomeSheet.ChangeAttendanceConfirm(
                    dateLabel = todayCard?.day?.dateLabel.orEmpty(),
                    shiftWindowLabel = todayCard?.day?.shiftWindowLabel.orEmpty(),
                    isProvisional = isProvisional,
                )
            },
        )
        if (_uiState.value.sheet is HomeSheet.ChangeAttendanceConfirm) {
            homeAnalytics.changeAttendanceSheetShown(
                currentStatus = todayCard?.status?.name?.lowercase() ?: "unknown",
            )
        }
    }

    /** Show the runner-consent sheet on home when consent isn't given: re-evaluate on each profile push
     *  and whenever the sheet slot frees, so the non-dismissable sheet reliably returns until consent. */
    private fun observeKavachConsent() {
        val gate = kavachConsent ?: return
        val store = profileStore ?: return
        viewModelScope.launch {
            combine(store.state, _uiState.map { it.sheet == null }.distinctUntilChanged()) { _, slotFree -> slotFree }
                .collect { slotFree ->
                    if (!slotFree || !gate.shouldShow()) return@collect
                    // A suspended / see-you-tomorrow full-hero takeover owns the whole hero and re-nulls
                    // `sheet` on every 1s ticker tick — showing consent there flickers the sheet and
                    // re-fires the analytics event once a second. Skip while a takeover holds the slot.
                    val s = _uiState.value
                    if (s.sheet != null ||
                        s.heroCards.any { it is HomeCard.Suspended || it is HomeCard.SeeYouTomorrow }
                    ) return@collect
                    analytics.track(
                        "expert_shield_consent_bs",
                        // Sheet only shows while consent is not-yet-given, so consent_given is always "N" here.
                        mapOf("runner_id" to store.snapshot()?.expertId, "consent_given" to "N", "source" to "home_page"),
                    )
                    _uiState.update { if (it.sheet == null) it.copy(sheet = HomeSheet.KavachConsent) else it }
                }
        }
    }

    private fun dismissSheet() {
        // Closing the sheet manually cancels the pending logout intent.
        // The runner abandoned the logout flow before answering attendance.
        _uiState.value = _uiState.value.copy(
            sheet = null,
            pendingLogoutAfterAttendance = false,
        )
    }

    /**
     * Logout tap is two-stage on `PA_BEFORE_LOGOUT`:
     *  - If the BE still wants tomorrow's attendance
     *    (`tomorrowAttendanceRequired`), open the MarkTomorrowAttendance
     *    sheet instead of firing the logout. The user marks Yes/No, BE
     *    flips the envelope to `RUNNER_LOGOUT`, and the next Logout tap
     *    actually logs out.
     *  - Otherwise (`RUNNER_LOGOUT` directly), run the logout use case.
     */
    private fun handleTapLogout() {
        val shift = readModel.state.value
        if (shift?.tomorrowAttendanceRequired == true) {
            _uiState.value = _uiState.value.copy(
                sheet = HomeSheet.MarkTomorrowAttendance(
                    dateLabel = shift.tomorrow?.dateLabel.orEmpty(),
                    shiftWindowLabel = shift.tomorrow?.shiftWindowLabel.orEmpty(),
                ),
                // Capture the runner's logout intent so the success of the
                // upcoming markProvisional call auto-chains shiftLogout —
                // they shouldn't have to tap Logout twice.
                pendingLogoutAfterAttendance = true,
            )
            homeAnalytics.markAttendanceSheetShown("post_logout")
        } else {
            launchAction(
                HomeUiIntent.TapLogout,
                block = { shiftRepository.shiftLogout() },
                onSuccess = { outcome -> outcome?.let { postActionCoordinator.show(it) } },
            )
        }
    }

    /**
     * The MVI "middleware" path for asynchronous actions: dismiss any open
     * sheet, mark the intent in-flight (drives button disable + double-tap
     * guard), invoke the use case, then on success ask the read model to
     * refresh (the Dart-side `RunnerStateChannel` reverse hop re-publishes
     * the next `current_state` envelope, which drives the card visual flip).
     * On failure emit a [HomeUiEffect.ShowSnackbar] with a localized
     * message. Single-flight: a second tap while a call is pending is a
     * no-op.
     */
    /**
     * Change-attendance has an extra precondition: the server requires
     * `shift_date` (mirrors Dart `attendance_confirmed.dart:59`). Pull
     * `startDateIst` from the today card; if it's missing the call would
     * silently no-op server-side, so we surface a snackbar instead of firing.
     */
    private fun handleConfirmChange(intent: HomeUiIntent.ConfirmChangeAttendance) {
        val shiftDate = (_uiState.value.heroCards.firstOrNull {
            it is HomeCard.Attendance.TodayStatus
        } as? HomeCard.Attendance.TodayStatus)?.day?.startDateIst
        if (shiftDate.isNullOrBlank()) {
            _effects.tryEmit(HomeUiEffect.ShowSnackbar(RunnerActionError.Unknown()))
            return
        }
        homeAnalytics.changeAttendance(present = intent.present)
        homeAnalytics.setNextShiftAttendance(intent.present)
        launchAction(
            intent,
            onSuccess = { outcome ->
                outcome?.let { postActionCoordinator.show(it) }
                // START_OT probe after a successful attendance change (Flutter onAttendanceMarked).
                autoOtCoordinator?.onAttendanceMarked()
            },
        ) { attendanceRepository.changeAttendance(intent.present, shiftDate) }
    }

    /**
     * Generic over the success payload [T] so actions that return a gamification
     * [com.snabbit.runner.shared.features.gamification.domain.model.PostActionOutcome]
     * (e.g. logout) can surface the reward/penalty popup via [onSuccess], while
     * value-less actions (lunch, attendance) pass `T = Unit` and the default no-op.
     */
    private fun <T> launchAction(
        intent: HomeUiIntent,
        onSuccess: suspend (T) -> Unit = {},
        block: suspend () -> Result<T, RunnerActionError>,
    ) {
        if (_uiState.value.inFlight != null) return
        _uiState.value = _uiState.value.copy(inFlight = intent)
        viewModelScope.launch {
            val result = block()
            // Read the flag before it is cleared — the Ok branch below still needs
            // to know whether this action began life as a Logout tap.
            val wasPendingLogout = _uiState.value.pendingLogoutAfterAttendance
            // Cleared unconditionally, alongside the sheet. Clearing it only on Ok
            // left it armed after a failed mark — and because MarkTomorrowAttendance
            // is not dismissible, there was no way back: the next successful
            // provisional mark, days later, would auto-chain a logout the runner
            // never asked for.
            _uiState.value = _uiState.value.copy(
                inFlight = null,
                sheet = null,
                pendingLogoutAfterAttendance = false,
            )
            when (result) {
                is Result.Ok -> {
                    // WS5: the post-action state (new attendance status, logout
                    // envelope) arrives via the MQTT snapshot. Feature #4: arm the
                    // timed fallback — if that snapshot doesn't land within the RC
                    // window, the engine fetches current_state once AND reports the
                    // miss (so the fail-loud gap stays observable in telemetry).
                    onSuccess(result.value)
                    readModel.onPostAction(intent.postActionLabel())
                    if (intent == HomeUiIntent.TapLogout) homeAnalytics.logoutSuccess()
                    // Two-stage logout: a successful ConfirmMarkProvisional
                    // that was opened from a Logout tap auto-chains the
                    // actual shiftLogout — the runner shouldn't have to tap
                    // Logout a second time after answering the attendance
                    // question. `wasPendingLogout` was captured before the flag was
                    // cleared unconditionally (blocker-1 fix), so a failed mark can't
                    // leave it armed to auto-logout a later, unrelated provisional mark.
                    if (intent is HomeUiIntent.ConfirmMarkProvisional && wasPendingLogout) {
                        launchAction(
                            HomeUiIntent.TapLogout,
                            block = { shiftRepository.shiftLogout() },
                            onSuccess = { outcome ->
                                outcome?.let { postActionCoordinator.show(it) }
                                // Dart PA_BEFORE_LOGOUT parity: rate-card-v2 runners land on
                                // the shift-end earnings summary after the attendance-chained
                                // logout (Dart's "View Today's Earnings" button, v2-only). v1
                                // runners — and the direct RUNNER_LOGOUT path above — get no
                                // earnings step. Read the flag from the live profile, NOT
                                // suspendedReadModel.info (that projection is null unless the
                                // runner is RUNNER_SUSPENDED — never true at logout).
                                if (profileStore?.snapshot()?.isRateCardV2Effective == true) {
                                    _effects.tryEmit(HomeUiEffect.NavigateToShiftEndEarnings)
                                }
                            },
                        )
                    }
                }
                is Result.Err -> {
                    _effects.tryEmit(HomeUiEffect.ShowSnackbar(result.error))
                    // Transient snackbar error → error_screen_load (X.3). One-shot: this branch runs once
                    // per action (guarded by `inFlight` above), so it never re-fires on recomposition.
                    val (errorType, errorContext) = intent.errorDescriptor()
                    errorAnalytics.errorScreenLoad(
                        errorType = errorType,
                        errorFormat = "snackbar",
                        errorContext = errorContext,
                        isNetworkError = result.error is RunnerActionError.NoConnection,
                        retryAvailable = false,
                        contactSupportAvailable = false,
                    )
                }
            }
        }
    }

    /**
     * Stable feature-#4 telemetry label for the post-action fallback. Explicit
     * strings (NOT `intent::class.simpleName`, which R8 obfuscates in release —
     * the label would be unstable garbage). `else` covers any future launchAction
     * intent until it's given its own label.
     */
    private fun HomeUiIntent.postActionLabel(): String = when (this) {
        is HomeUiIntent.ConfirmMarkProvisional -> "attendance_provisional"
        is HomeUiIntent.ConfirmChangeAttendance -> "attendance_change"
        HomeUiIntent.AcceptLunch -> "lunch_accept"
        HomeUiIntent.DenyLunch -> "lunch_deny"
        HomeUiIntent.ConfirmEndBreak -> "break_end"
        HomeUiIntent.TapLogout -> "shift_logout"
        else -> "home_action"
    }

    /** Maps a failed `launchAction` intent to its `error_screen_load` (`error_type`, `error_context`)
     *  for the X.3 transient-error instrumentation. `else` is a defensive fallback for any future
     *  launchAction intent until it earns its own values (pending PM sign-off). */
    private fun HomeUiIntent.errorDescriptor(): Pair<String, String> = when (this) {
        is HomeUiIntent.ConfirmMarkProvisional -> "mark_attendance_failed" to "attendance"
        is HomeUiIntent.ConfirmChangeAttendance -> "change_attendance_failed" to "attendance"
        HomeUiIntent.AcceptLunch, HomeUiIntent.DenyLunch, HomeUiIntent.ConfirmEndBreak ->
            "lunch_action_failed" to "home"
        HomeUiIntent.TapLogout -> "logout_failed" to "logout"
        else -> "home_action_failed" to "home"
    }

    private companion object {
        const val TAG = "HomeViewModel"

        /** Spec-dictionary `home_primary_state` values eligible for the
         *  `current_home_state` profile $set — excludes KMP-only `idle`/`suspended`. */
        val DICTIONARY_HOME_STATES = setOf(
            "provisional_attendance", "present_prelogin", "login_window_open",
            "no_show_today", "idle_state_map", "lunch_break", "shift_ending",
        )

        const val SEVA_HELPER_AUTO_DISMISS_MS = 5_000L

        /** Radius (m) for `seva/nearby`. The backend caps at 1000 m (see
         *  [SevaRemoteDataSource.MAX_RADIUS_M]); we request the max so each fetch
         *  covers ~4× the area of the 500 m default and the runner walks twice as
         *  far before a refetch. Markers are still nearest-first capped at
         *  [MAX_SEVA_MARKERS], so a wider payload never floods the map. */
        const val SEVA_FETCH_RADIUS_M = 1000

        /** Refetch `seva/nearby` once the runner moves this far (m) from the last
         *  fetch centre — half the [SEVA_FETCH_RADIUS_M] fetch radius, so coverage
         *  never gaps but the GPS stream doesn't spam the endpoint. */
        const val SEVA_REFETCH_MOVE_M = 500.0

        /** Dark chip label on the seva helper card. Same for washroom + resting
         *  in MVP (Figma 969:56727 shows a single "Seva" tag). */
        const val SEVA_TAG_LABEL = "Seva"

        /** CleverTap/Mixpanel event for the end-break confirm tap (mirrors
         *  Flutter `TrackingEvents.breakConfirmEndButtonClicked`). */
        const val BREAK_CONFIRM_END_EVENT = "break_confirm_end_button_clicked"

        /** Break-ring color bands, as a fraction of the break's total length
         *  remaining: below this → red. */
        const val RED_THRESHOLD = 0.3f

        /** Below this (and not already red) → amber; otherwise green. */
        const val AMBER_THRESHOLD = 0.5f

        /** CleverTap/Mixpanel event for the Saathi pill tap (parity with the Flutter
         *  home Help chip's `home_help_button_clicked`). */
        const val SAATHI_TAP_EVENT = "home_saathi_button_clicked"

        /** Remote Config key for the Saathi helpline number (degrades to
         *  [DEFAULT_SAATHI_NUMBER] when RC is unavailable). */
        const val RC_SAATHI_HELPLINE = "expert_saathi_helpline_number"

        const val RC_SAATHI_TICKETING = "expert_enable_saathi_ticketing"

        /** Bool kill-switch for the top-nav red card pill. Default OFF on both sides
         *  (see Dart `KmpRemoteConfigMirror`) — absent RC ⇒ hidden, never a wrong gate. */
        const val RC_SHOW_RED_CARD_PILL = "expert_show_red_card_pill"

        /** Default Saathi helpline — app-webview's "Call Saathi" number — used when RC
         *  is unset. */
        const val DEFAULT_SAATHI_NUMBER = "02244582683"

        /** Reactivation-request event (mirrors Flutter
         *  `TrackingEvents.expertWantsToJoinBack`). `action` ∈
         *  {success, denied, failed}. */
        const val EXPERT_WANTS_TO_JOIN_BACK = "expert_wants_to_join_back"

        /** Shimmer gives up after this if no envelope ever lands (stuck bridge /
         *  no shift). Generous — a healthy push arrives in well under a second. */
        val FIRST_LOAD_TIMEOUT = 10.seconds

        /** CleverTap/Mixpanel event for a "More From Snabbit" banner tap. */
        const val BANNER_CLICK_EVENT = "home_banner_clicked"

        /** `entry_point` attribution for the fallback's referrals-v2 webview hop
         *  (mirrors "profile_menu" / "refer_tab" on the other refer surfaces). */
        const val BANNER_REFER_ENTRY_POINT = "home_banner"

        /** `entry_point` attribution for the see-you-tomorrow card's "Refer and
         *  Earn" CTA — distinguishes it from the banner refer tap in the
         *  referrals-v2 webview. Only surfaces on the v2 path (the native
         *  `/referral-home` fallback carries no `entry_point`). */
        const val SEE_YOU_TOMORROW_REFER_ENTRY_POINT = "see_you_tomorrow"

        // `cmp:<key>` (native CMP destination registry) is part of the BE path
        // contract (LLD §8.2) but deliberately NOT implemented until the first
        // CMP banner destination exists (G1) — until then it falls through to
        // the unknown-path breadcrumb, which is already forward-compatible.

        /** `clickPath` prefix for client-resolved targets ([openDeciderTarget]). */
        const val DECIDER_PATH_PREFIX = "decider:"

        /** `decider:refer` — referrals v2 RC gate → webview vs native ReferralsHome. */
        const val DECIDER_REFER = "refer"

        /** `decider:earnings` — rate-card v2 → monthly-summary webview vs PayoutHome. */
        const val DECIDER_EARNINGS = "earnings"

        /**
         * Client-side fallback so the section never goes blank — today's shipped
         * Refer banner, shown until the BE list lands and kept when the fetch
         * fails or returns empty (LLD §8.3). Blank [Banner.bgImageUrl] → the
         * bundled Refer artwork (`home_banner_refer_fallback.webp`). Copy is
         * frozen at the pre-BE seed values; BE owns fresher copy via the
         * endpoint. Its tap routes through [ProfileRouteDecider.referAndEarn]
         * (see [handleTapBanner]) — [Banner.clickPath] here only feeds the
         * analytics props.
         */
        val REFER_FALLBACK = Banner(
            id = "refer_fallback",
            title = "Refer and earn upto",
            subtitle = "₹4000",
            ctaLabel = "Refer Now",
            clickPath = "/referral-home",
        )
    }

    private fun initialState(phase: ShiftPhase) = HomeUiState(
        phase = phase,
        // Shimmer only if the store hasn't already delivered an envelope — a
        // mid-shift mount onto a warm ShiftProjector skips the shimmer entirely.
        isLoading = !readModel.hasLoaded.value,
        heroCards = emptyList(),
        bodyCards = emptyList(),
        // Empty + shimmering until the first fetch resolves; refreshBanners()
        // delivers the BE list, or the Refer fallback on error/empty.
        moreFromSnabbit = emptyList(),
        bannersLoading = true,
    )
}
