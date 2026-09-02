package com.snabbit.runner.shared.features.home.presentation

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.core.MutableTransitionState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectVerticalDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.ui.graphics.Brush
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.BottomSheetScaffold
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.SheetValue
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.material3.pulltorefresh.PullToRefreshDefaults
import androidx.compose.material3.pulltorefresh.rememberPullToRefreshState
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.material3.rememberBottomSheetScaffoldState
import androidx.compose.material3.rememberStandardBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.snapshotFlow
import kotlinx.coroutines.flow.filter
import kotlinx.coroutines.flow.first
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.layout
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.snabbit.design.atoms.SnabbitToast
import com.snabbit.design.atoms.SnabbitToastVariant
import com.snabbit.design.theme.SnabbitColorsLight
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.features.home.domain.model.HomeBg
import com.snabbit.runner.shared.features.home.domain.model.MapFloatingState
import com.snabbit.runner.shared.features.home.domain.model.bg
import com.snabbit.runner.shared.features.gamification.domain.model.PreActionNudge
import com.snabbit.runner.shared.features.home.presentation.ui.sheets.ChangeAttendancePenalty
import com.snabbit.runner.shared.features.home.presentation.ui.HeroSection
import com.snabbit.runner.shared.features.home.presentation.ui.HomeCardRenderer
import com.snabbit.runner.shared.features.home.presentation.ui.HomeHeroShimmer
import com.snabbit.runner.shared.features.home.presentation.ui.HomeTopNav
import com.snabbit.runner.shared.features.home.presentation.ui.MAX_SEVA_MARKERS
import com.snabbit.runner.shared.features.home.presentation.ui.MapBackground
import com.snabbit.runner.shared.features.home.presentation.ui.MapBackgroundDefaultCoords
import com.snabbit.runner.shared.features.home.presentation.ui.MapCoords
import com.snabbit.runner.shared.features.home.presentation.ui.SevaMarker
import com.snabbit.runner.shared.features.home.presentation.ui.MoreFromSnabbitSection
import com.snabbit.runner.shared.features.home.presentation.ui.cards.MapFloatingWidget
import com.snabbit.runner.shared.features.home.presentation.ui.cards.SevaHelperCard
import com.snabbit.runner.shared.core.designsystem.SnabbitScreen
import com.snabbit.runner.shared.core.designsystem.components.HeaderNavPill

/**
 * The runner Home screen — Compose Multiplatform.
 *
 * Two layouts, picked by `phase.bg()`:
 *  - **Hero** (Pink / Grey): wrapped in [SnabbitScreen]; single [LazyColumn]
 *    with the hero (top nav + heroCards) as the first item.
 *  - **Map**: full-bleed map background + floating top nav + draggable
 *    [BottomSheetScaffold] that holds bodyCards + "More From Snabbit" and can
 *    be dragged from a peek state up to full screen.
 *
 * Home owns its top nav (composed inside the hero / floating over the map) —
 * SnabbitScreen's title slot is unused. The bottom tab bar lives in the
 * Flutter shell during migration.
 *
 * ponytail: material3 `BottomSheetScaffold` is used as a layout primitive
 * because the DS doesn't ship a sheet host. DS components fill the sheet
 * content. Replace the BottomSheetScaffold container the moment DS adds
 * `SnabbitBottomSheet`.
 */
@Composable
fun HomeScreen(
    viewModel: HomeViewModel,
    strings: HomeStrings = rememberHomeStrings(),
    modifier: Modifier = Modifier,
    /**
     * True while an in-app AWOL condition is showing (breach or re-entered). When true
     * the home forces the Pink hero archetype and renders [awolCard] as the SOLE hero
     * content — the full-screen map / searching bottom sheet and the attendance/hero
     * cards are all hidden until the server clears the AWOL state (awolActive -> false).
     */
    awolActive: Boolean = false,
    /**
     * The in-app AWOL card (HOME_CARD surface). Injected as a slot so `HomeScreen`
     * stays DI-free: the Home-tab host builds it from the shared
     * `AwolViewModel` + distance tracker (gated on `homeCardEnabled`); previews pass
     * nothing. Rendered inside the pink hero panel (replacing the hero cards) only
     * while [awolActive]; self-collapses to zero if the coordinator drops HOME_CARD.
     */
    awolCard: @Composable () -> Unit = {},
    /**
     * FALSE_ATTENDANCE penalty chrome for the [HomeSheet.ChangeAttendanceConfirm]
     * sheet, derived host-side from the decoded `sheet_warnings` (the Home-tab
     * host threads it from [com.snabbit.runner.shared.features.gamification.data.GamificationProjector]).
     * Null → plain calendar sheet (previews/tests default). Kept off the VM so
     * `HomeScreen` stays DI-free of gamification, threaded as a slot.
     */
    changeAttendancePenalty: ChangeAttendancePenalty? = null,
    /**
     * EARLY_LOGIN pre-action nudge docked under the TodayStatus Present card
     * (Figma DS 87-25340), host-threaded from `gamState.nudges`. Null → no strip.
     */
    loginNudge: PreActionNudge? = null,
    /**
     * Tiering surfaces (Snabbit Udaan intro banner + the applicable tier nudge),
     * rendered just above the "More From Snabbit" strip in both archetypes —
     * mirroring the Flutter `partner_home` placement (after the main content,
     * before the promo banners). DI-free slot: the Home-tab host builds it from
     * the shared `TieringViewModel` (all visibility lives in `TieringUiState`);
     * previews/tests pass nothing. Self-collapses to zero height when there's
     * neither a banner nor a nudge to show.
     */
    tieringSection: @Composable () -> Unit = {},
    /**
     * App-bar tier badge — when non-null (tiering live), it replaces the
     * gold-coins pill in the top nav (Flutter `partner_home` parity). Host-built
     * from `TieringUiState.tierBadge` (the date-gated surface, distinct from the
     * profile card's tier-identity gate); previews/tests pass nothing (coins shown).
     */
    tierPill: HeaderNavPill? = null,
) {
    val state by viewModel.uiState.collectAsState()
    val onIntent = viewModel::onIntent
    // One-shot effect collector. `LaunchedEffect(Unit)` re-creates only on
    // recomposition with a new key (never here), so the SharedFlow is collected
    // exactly once per HomeScreen instance — late re-collectors don't replay
    // prior snackbars. See [HomeUiEffect].
    val snackbarHostState = remember { SnackbarHostState() }
    val uriHandler = LocalUriHandler.current
    LaunchedEffect(Unit) {
        viewModel.effects.collect { effect ->
            when (effect) {
                is HomeUiEffect.ShowSnackbar ->
                    snackbarHostState.showSnackbar(effect.message ?: strings.errorFor(effect.error))
                // Nav effect — the Home-tab host collects it independently to push
                // the ShiftLogin destination. Ignored here.
                HomeUiEffect.NavigateToShiftLogin -> Unit
                // Suspended-card nav effects — the Home-tab host bridges these to
                // Dart routes (Aadhaar re-KYC / earnings). Ignored here.
                HomeUiEffect.NavigateToAadhaarReKyc -> Unit
                is HomeUiEffect.NavigateToEarnings -> Unit
                HomeUiEffect.NavigateToShiftEndEarnings -> Unit
                // Universal Google Maps directions URL: resolves to the Maps app
                // if installed, else the browser (system chooser). Directions mode.
                is HomeUiEffect.OpenDirections -> uriHandler.openUri(
                    "https://www.google.com/maps/dir/?api=1" +
                        "&destination=${effect.lat},${effect.lng}&travelmode=driving",
                )
            }
        }
    }
    // Home owns its custom top nav (composed inside the hero / floating over
    // the map) — no `onNavigateUp` slot here. System back-press finishes the
    // host Activity; add the param back when a navigator threads through.
    // The Map archetype and `HomeSheetHost` render outside SnabbitScreen, so
    // wrap here in SnabbitTheme — which (DS 0.15.0+) also supplies Outfit + colors
    // to everything Home composes.
    SnabbitTheme(darkTheme = false) {
        // AWOL takeover: whenever an in-app AWOL card is routed (breach or re-entered),
        // force the Pink archetype so the card shows inside the pink hero panel — never
        // the full-screen map / searching bottom sheet. Reverts to the normal archetype
        // the moment the server clears the AWOL state (awolActive -> false).
        val bg = if (awolActive) HomeBg.Pink else state.phase.bg()
        // Wrap the archetype so the Saathi feedback toast overlays BOTH the hero and
        // map layouts from a single placement (the Saathi pill lives in the top nav,
        // present across archetypes). fillMaxSize keeps each archetype's own sizing.
        Box(modifier = Modifier.fillMaxSize()) {
            when (bg) {
                HomeBg.Pink, HomeBg.Grey -> HeroLayout(
                    state = state,
                    strings = strings,
                    onIntent = onIntent,
                    snackbarHostState = snackbarHostState,
                    bg = bg,
                    awolActive = awolActive,
                    awolCard = awolCard,
                    modifier = modifier,
                    loginNudge = loginNudge,
                    tieringSection = tieringSection,
                    tierPill = tierPill,
                )
                // Map archetype (SearchingForJobs): map is the SCREEN BACKGROUND,
                // floating widget at the bottom. No hero, no body cards, no
                // BottomSheetScaffold — chrome-level composition only. AWOL never
                // reaches here (it forces Pink above), so the map carries no AWOL card.
                HomeBg.Map -> MapLayout(
                    state = state,
                    strings = strings,
                    onIntent = onIntent,
                    snackbarHostState = snackbarHostState,
                    modifier = modifier,
                    tieringSection = tieringSection,
                    tierPill = tierPill,
                )
            }

            // Saathi support-call feedback (Flutter parity) — DS toast, bottom-aligned like
            // the existing Home snackbar so it clears the top nav. Success (green) on IVR 2xx,
            // Error (red) on a blank number; the dialer fallback shows nothing. Auto-dismiss
            // clears the state via [HomeUiIntent.SaathiCallFeedbackShown].
            state.saathiCallFeedback?.let { feedback ->
                SnabbitToast(
                    title = strings.saathiFeedbackFor(feedback),
                    variant = if (feedback == SaathiCallFeedback.CallInitiated) {
                        SnabbitToastVariant.Success
                    } else {
                        SnabbitToastVariant.Error
                    },
                    durationMillis = SAATHI_TOAST_DURATION_MS,
                    onDismiss = { onIntent(HomeUiIntent.SaathiCallFeedbackShown) },
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .fillMaxWidth()
                        .padding(16.dp),
                )
            }
        }

        // Sheets overlay the layout. material3 `ModalBottomSheet` handles its
        // own scrim + animation, so it's safe to render after the archetype.
        // Suppressed while the GPS gate is active (ECPO-873 reduced scope): on
        // cold start both `state.sheet` (e.g. KavachConsent) and
        // `state.locationServiceOff` can be non-null simultaneously, and stacking
        // two SnabbitBottomSheet scrims is a visual bug. The GPS gate always wins —
        // EnableLocationSheet renders below regardless.
        if (!state.locationServiceOff) {
            HomeSheetHost(
                sheet = state.sheet,
                inFlight = state.inFlight,
                strings = strings,
                onIntent = onIntent,
                changeAttendancePenalty = changeAttendancePenalty,
            )
        }

        // GPS-off hard gate (ECPO-873, reduced scope). Rendered last → sits above
        // the archetype and any HomeSheetHost sheet; blocks Home until GPS is back on.
        com.snabbit.runner.shared.features.home.presentation.ui.sheets.EnableLocationSheet(
            visible = state.locationServiceOff,
            strings = strings,
            onEnable = { onIntent(HomeUiIntent.EnableLocation) },
        )
    } // SnabbitTheme
}

@Composable
private fun HomeSheetHost(
    sheet: HomeSheet?,
    inFlight: HomeUiIntent?,
    strings: HomeStrings,
    onIntent: (HomeUiIntent) -> Unit,
    changeAttendancePenalty: ChangeAttendancePenalty? = null,
) {
    // The DS SnabbitBottomSheet is a Popup driven by `visible`; keep the last
    // non-null sheet so its content survives the slide-out after `sheet` clears.
    var lastSheet by remember { mutableStateOf<HomeSheet?>(null) }
    if (sheet != null) lastSheet = sheet
    // Derive per-button loading flags from the single in-flight intent so each
    // sheet shows the spinner on the pressed button (and disables the other).
    val markAbsentLoading = inFlight == HomeUiIntent.ConfirmMarkProvisional(present = false)
    val markPresentLoading = inFlight == HomeUiIntent.ConfirmMarkProvisional(present = true)
    val changeAbsentLoading = inFlight == HomeUiIntent.ConfirmChangeAttendance(present = false)
    val changePresentLoading = inFlight == HomeUiIntent.ConfirmChangeAttendance(present = true)
    // Dismissal stays enabled during in-flight actions: single-flight in
    // `launchAction` prevents double-submission, and the launched coroutine
    // clears the sheet + emits snackbars regardless of an interim dismissal.
    // Non-dismissible sheets (e.g. the waiver) still gate close via `dismissible`.
    val dismissible = lastSheet?.dismissible ?: true
    com.snabbit.design.organisms.SnabbitBottomSheet(
        visible = sheet != null,
        onDismissRequest = { if (dismissible) onIntent(HomeUiIntent.DismissSheet) },
        showClose = dismissible,
        contentDescription = strings.sheetCloseContentDescription,
    ) {
        when (val sheet = lastSheet) {
            is HomeSheet.EarningLoss -> {
                // Mode picks the target intent: MarkTomorrow → provisional,
                // ChangeToday → change. Loading flags follow the same split.
                val isChange = sheet.mode == HomeSheet.EarningLoss.Mode.ChangeToday
                val absentIntent = if (isChange) {
                    HomeUiIntent.ConfirmChangeAttendance(present = false)
                } else {
                    HomeUiIntent.ConfirmMarkProvisional(present = false)
                }
                val presentIntent = if (isChange) {
                    HomeUiIntent.ConfirmChangeAttendance(present = true)
                } else {
                    HomeUiIntent.ConfirmMarkProvisional(present = true)
                }
                val absentLoading = if (isChange) changeAbsentLoading else markAbsentLoading
                val presentLoading = if (isChange) changePresentLoading else markPresentLoading
                com.snabbit.runner.shared.features.home.presentation.ui.sheets.EarningLossSheet(
                    amount = sheet.amount,
                    strings = strings,
                    onMarkAbsent = { onIntent(absentIntent) },
                    onMarkPresent = { onIntent(presentIntent) },
                    loadingAbsent = absentLoading,
                    loadingPresent = presentLoading,
                )
            }
            is HomeSheet.MarkTomorrowAttendance ->
                com.snabbit.runner.shared.features.home.presentation.ui.sheets.MarkTomorrowAttendanceSheet(
                    dateLabel = sheet.dateLabel,
                    shiftWindowLabel = sheet.shiftWindowLabel,
                    strings = strings,
                    onMarkAbsent = { onIntent(HomeUiIntent.ConfirmMarkProvisional(present = false)) },
                    onMarkPresent = { onIntent(HomeUiIntent.ConfirmMarkProvisional(present = true)) },
                    loadingAbsent = markAbsentLoading,
                    loadingPresent = markPresentLoading,
                )
            is HomeSheet.ChangeAttendanceConfirm ->
                com.snabbit.runner.shared.features.home.presentation.ui.sheets.ChangeAttendanceConfirmSheet(
                    dateLabel = sheet.dateLabel,
                    shiftWindowLabel = sheet.shiftWindowLabel,
                    strings = strings,
                    onConfirmAbsent = { onIntent(HomeUiIntent.ConfirmChangeAttendance(present = false)) },
                    onConfirmPresent = { onIntent(HomeUiIntent.ConfirmChangeAttendance(present = true)) },
                    loadingAbsent = changeAbsentLoading,
                    loadingPresent = changePresentLoading,
                    // Provisional/tomorrow change never carries the FALSE_ATTENDANCE
                    // red-card penalty — that chrome is today-only.
                    penalty = if (sheet.isProvisional) null else changeAttendancePenalty,
                )
            is HomeSheet.RedCardsWaived ->
                com.snabbit.runner.shared.features.home.presentation.ui.sheets.WaiverSheet(
                    redCardCount = sheet.redCardCount,
                    strings = strings,
                    onAcknowledge = { onIntent(HomeUiIntent.AcknowledgeWaiver) },
                )
            HomeSheet.LunchRequest ->
                com.snabbit.runner.shared.features.home.presentation.ui.sheets.LunchRequestSheet(
                    strings = strings,
                    onTakeBreak = { onIntent(HomeUiIntent.AcceptLunch) },
                    onSkip = { onIntent(HomeUiIntent.DenyLunch) },
                    takeLoading = inFlight == HomeUiIntent.AcceptLunch,
                    skipLoading = inFlight == HomeUiIntent.DenyLunch,
                )
            HomeSheet.EndBreakConfirm ->
                com.snabbit.runner.shared.features.home.presentation.ui.sheets.EndBreakConfirmSheet(
                    strings = strings,
                    onEndBreak = { onIntent(HomeUiIntent.ConfirmEndBreak) },
                    onGoBack = { onIntent(HomeUiIntent.DismissSheet) },
                    endLoading = inFlight == HomeUiIntent.ConfirmEndBreak,
                )
            HomeSheet.KavachConsent ->
                com.snabbit.runner.shared.features.kavach.shared.ui.components.ConsentSheetContent(
                    onAgree = { onIntent(HomeUiIntent.ConfirmKavachConsent) },
                    loading = inFlight == HomeUiIntent.ConfirmKavachConsent,
                )
            null -> Unit
        }
    }
}

/**
 * The runner top nav, pinned as a fixed overlay (status-bar inset + hero
 * gutters) so it's always present and never scrolls. Shared by both
 * archetypes — the single placement of [HomeTopNav].
 */
@Composable
private fun PinnedTopNav(
    strings: HomeStrings,
    onIntent: (HomeUiIntent) -> Unit,
    modifier: Modifier = Modifier,
    sosVisible: Boolean = true,
    coinsCount: Int = 0,
    redCardsCount: Int = 0,
    coinsVisible: Boolean = true,
    redCardVisible: Boolean = false,
    tierPill: HeaderNavPill? = null,
) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .windowInsetsPadding(WindowInsets.statusBars)
            // 20dp top gap below the status bar — visual rhythm per Figma
            // 76:35279 (bell sits a comfortable distance under the system bar).
            .padding(
                top = SnabbitTheme.spacing.`6`,
                start = SnabbitTheme.spacing.`6`,
                end = SnabbitTheme.spacing.`6`,
                bottom = SnabbitTheme.spacing.`4`,
            ),
    ) {
        HomeTopNav(
            strings = strings,
            onIntent = onIntent,
            sosVisible = sosVisible,
            coinsCount = coinsCount,
            redCardsCount = redCardsCount,
            coinsVisible = coinsVisible,
            redCardVisible = redCardVisible,
            tierPill = tierPill,
        )
    }
}

// ────────────────────────── Hero archetype ────────────────────────────
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun HeroLayout(
    state: HomeUiState,
    strings: HomeStrings,
    onIntent: (HomeUiIntent) -> Unit,
    snackbarHostState: SnackbarHostState,
    // The already-resolved archetype background (AWOL takeover folded in by
    // HomeScreen) — the single decision point; do not re-derive from state here.
    bg: HomeBg,
    awolActive: Boolean,
    awolCard: @Composable () -> Unit,
    modifier: Modifier,
    loginNudge: PreActionNudge? = null,
    tieringSection: @Composable () -> Unit = {},
    tierPill: HeaderNavPill? = null,
) {
    SnabbitScreen(
        modifier = modifier,
        title = null,
        snackbarHostState = snackbarHostState,
    ) { padding ->
        Box(modifier = Modifier.fillMaxSize()) {
            // ponytail: fixed 700ms spinner because the read model's
            // requestRefresh() is fire-and-forget — no completion signal to
            // hook. Upgrade to a state-driven `isRefreshing` flag the moment
            // ShiftProjector exposes one.
            val scope = rememberCoroutineScope()
            var isRefreshing by remember { mutableStateOf(false) }
            val pullState = rememberPullToRefreshState()
            PullToRefreshBox(
                isRefreshing = isRefreshing,
                onRefresh = {
                    isRefreshing = true
                    onIntent(HomeUiIntent.Load)
                    scope.launch {
                        delay(700)
                        isRefreshing = false
                    }
                },
                // No bottom inset here. Home is only ever hosted inside the tab
                // shell, whose Scaffold already reserves the bar's full height —
                // and the bar's NavigationBar folds the navigation-bar inset into
                // that height. SnabbitScreen's own Scaffold defaults to systemBars
                // content insets, so spending `padding.calculateBottomPadding()`
                // charged the same inset a second time and left a dead band above
                // the tab bar (UAT).
                modifier = Modifier.fillMaxSize(),
                state = pullState,
                // Default indicator anchors at the top of the box, which sits
                // BEHIND PinnedTopNav (status-bar inset + 80dp nav). Push it
                // below the nav so the user can actually see the spinner.
                indicator = {
                    PullToRefreshDefaults.Indicator(
                        modifier = Modifier
                            .align(Alignment.TopCenter)
                            .windowInsetsPadding(WindowInsets.statusBars)
                            .padding(top = 72.dp),
                        isRefreshing = isRefreshing,
                        state = pullState,
                    )
                },
            ) {
                val bannerListState = rememberLazyListState()
                LaunchedEffect(bannerListState) {
                    // home_screen_scrolled: fire once when the page scrolls far
                    // enough to reveal the "More From Snabbit" strip.
                    snapshotFlow {
                        bannerListState.layoutInfo.visibleItemsInfo.any { it.key == "more_from_snabbit" }
                    }.filter { it }.first()
                    onIntent(HomeUiIntent.HomeScrolled)
                }
                LazyColumn(
                    state = bannerListState,
                    // Drop Scaffold's top inset so the PinkHero (which carries
                    // its own 96dp top pad for the status bar + breathing
                    // room) draws all the way to the top of the window — pink
                    // bleeds up behind the transparent status bar per Figma
                    // 76:31041. Bottom inset is applied on PullToRefreshBox.
                    modifier = Modifier.fillMaxSize(),
                    // No `spacedBy`: an empty banner section is zero-height,
                    // and spacedBy still charges a full gap per child —
                    // stacking phantom space between the hero and the banner
                    // (ECPO-833 #2). Visible items own their 32dp bottom gap
                    // instead.
                ) {
                    item(key = "hero") {
                        // 32dp vertical rhythm to the next section, matching
                        // the Figma stack gap.
                        Box(Modifier.padding(bottom = SnabbitTheme.spacing.layoutGapLg)) {
                            HeroSection(bg = bg) {
                                if (awolActive) {
                                    awolCard()
                                } else if (state.isLoading) {
                                    HomeHeroShimmer()
                                } else {
                                    state.heroCards.forEach { card ->
                                        HomeCardRenderer(
                                            card = card,
                                            strings = strings,
                                            onIntent = onIntent,
                                            inFlight = state.inFlight,
                                            loginNudge = loginNudge,
                                            suspendRequestSubmitted = state.suspendRequestSubmitted,
                                        )
                                    }
                                }
                            }
                        }
                    }
                    items(state.bodyCards, key = { it.key }) { card ->
                        Box(Modifier.padding(bottom = SnabbitTheme.spacing.layoutGapLg)) {
                            HomeCardRenderer(card = card, strings = strings, onIntent = onIntent, inFlight = state.inFlight)
                        }
                    }
                    // Tiering (Udaan banner / applicable nudge) sits below the
                    // main content and above the promo strip — Flutter parity.
                    // The slot owns its gutter + bottom gap and collapses to zero
                    // when empty, so no phantom space when nothing renders.
                    item(key = "tiering") { tieringSection() }
                    item(key = "more_from_snabbit") {
                        MoreFromSnabbitSection(
                            banners = state.moreFromSnabbit,
                            strings = strings,
                            onIntent = onIntent,
                            isLoading = state.bannersLoading,
                        )
                    }
                }
            }
            // Hero-phase top scrim (ECPO-745). The pinned nav floats over the
            // scrolling list; without a backdrop, body cards slide visibly
            // through the transparent gaps around the nav pills as the hero
            // scrolls away. The scrim must be FULLY OPAQUE across the whole nav
            // band and only fade BELOW it — a plain top→bottom fade is already
            // ~half-transparent by the pill row (status-bar inset + ~84dp), so
            // scrolled cards showed through the pills (QA reopen 2026-07-17).
            // Height is the *measured* nav band (status-bar inset varies by
            // device — a magic constant is what let this regress), plus a short
            // fade tail that stays seamless over the PinkHero at rest.
            val density = LocalDensity.current
            var navBandHeight by remember { mutableStateOf(0.dp) }
            val scrimFade = SnabbitTheme.spacing.layoutGapLg
            val scrimHeight = navBandHeight + scrimFade
            Box(
                modifier = Modifier
                    .align(Alignment.TopCenter)
                    .fillMaxWidth()
                    .height(scrimHeight)
                    .background(
                        Brush.verticalGradient(
                            0f to SnabbitColorsLight.pink500,
                            // Hold opaque to the bottom of the nav, then fade.
                            (navBandHeight / scrimHeight).coerceIn(0f, 1f) to SnabbitColorsLight.pink500,
                            1f to SnabbitColorsLight.pink500.copy(alpha = 0f),
                        ),
                    ),
            )
            // Pinned header — overlays the scroll so the top nav is always
            // present (Figma 69-15873: bell/SOS/Saathi/coins never scroll away).
            // Same fixed-overlay treatment the Map archetype uses below. Its
            // measured height (status-bar inset + gaps + pills) drives the scrim.
            PinnedTopNav(
                strings = strings,
                onIntent = onIntent,
                sosVisible = state.sosVisible,
                coinsCount = state.coinsCount,
                redCardsCount = state.redCardsCount,
                coinsVisible = state.rewardsPillsVisible,
                redCardVisible = state.redCardPillVisible,
                tierPill = tierPill,
                modifier = Modifier.onSizeChanged {
                    navBandHeight = with(density) { it.height.toDp() }
                },
            )
        }
    }
}

// ────────────────────────── Map archetype ─────────────────────────────

/**
 * The stable part of the map-sheet top reserve — the chrome whose height doesn't
 * vary at runtime: the pinned nav (~72dp), the widget↔sheet gap (12dp) and the
 * drag handle (~34dp) that sits above the sheet content. The device status-bar
 * inset and the floating widget's own height are measured and added on top in
 * [MapLayout], so the reserve adapts to notches/gesture bars and to taller
 * widget variants (Logout / stacked Seva).
 */
private val MapSheetChromeSlack = 118.dp

/**
 * Map archetype — Figma 1582:7327. The map is the screen background
 * (full-bleed behind everything); a `BottomSheetScaffold` rides on top at
 * a 40%-of-viewport peek; the pinned top nav floats over the top edge.
 *
 * Sheet content from top → bottom:
 *  - The floating widget read from `state.mapWidget` (the "Searching for
 *    jobs nearby" pill at peek, Seva / Lunch / Logout as the lifecycle
 *    progresses).
 *  - `MoreFromSnabbit` banner section, visible when the user drags the
 *    sheet up past the peek.
 *
 * No duplicate map inside the sheet — the bg map IS the map.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun MapLayout(
    state: HomeUiState,
    strings: HomeStrings,
    onIntent: (HomeUiIntent) -> Unit,
    snackbarHostState: SnackbarHostState,
    modifier: Modifier,
    tieringSection: @Composable () -> Unit = {},
    tierPill: HeaderNavPill? = null,
) {
    val sheetState = rememberStandardBottomSheetState(
        initialValue = SheetValue.PartiallyExpanded,
        skipHiddenState = true,
    )
    val scaffoldState = rememberBottomSheetScaffoldState(bottomSheetState = sheetState)

    // (AWOL no longer surfaces here — an active in-app AWOL card forces the Pink hero
    // archetype in HomeScreen, so the map's bottom sheet never hosts the breach card.)

    // Map archetype refresh: a vertical drag detector on the map content
    // area. PullToRefreshBox can't go here — it needs a scrollable child
    // and the map background is non-scrollable. ponytail: fires on
    // drag-release past threshold; same fixed 700ms shim as HeroLayout.
    val scope = rememberCoroutineScope()
    var isRefreshing by remember { mutableStateOf(false) }
    var dragDistance by remember { mutableStateOf(0f) }
    val refreshThresholdPx = with(LocalDensity.current) { 80.dp.toPx() }

    // BoxWithConstraints gives us the viewport height — `LocalConfiguration`
    // is Android-only and would break commonMain purity.
    BoxWithConstraints(modifier = modifier.fillMaxSize()) {
        val density = LocalDensity.current
        // Cap how tall the sheet can get. Its top edge is where the floating
        // map widget (state.mapWidget / sevaAnnouncement) is anchored — without a
        // cap, dragging to full-expand pulls the sheet top to the screen top and
        // shoves the widget up behind the pinned nav. The reserve keeps the widget
        // parked below the nav and is built dynamically: device status-bar inset +
        // the widget's measured height (grows for stacked Seva / Logout variants) +
        // the fixed chrome ([MapSheetChromeSlack]). `floatingWidgetHeight` is fed
        // back from the overlay's onSizeChanged; 0 until first measure (and when no
        // widget is shown, so the sheet may expand further — nothing to keep clear).
        val statusBarTop = with(density) { WindowInsets.statusBars.getTop(this).toDp() }
        var floatingWidgetHeight by remember { mutableStateOf(0.dp) }
        val topReserve = statusBarTop + floatingWidgetHeight + MapSheetChromeSlack
        // Dynamic sheet (ECPO-748 follow-up), two anchors:
        //  - Collapsed = fixed 30% of the viewport — the minimum the runner
        //    can pull the sheet down to, so the map is always reachable.
        //  - Expanded = the sheet's own (content-wrapped) height, capped at
        //    the nav-safe [expandedSheetHeight] — whatever the content is,
        //    the sheet covers it, no more. The content Column wraps via
        //    `heightIn(max)`, so a banner-only sheet expands barely past the
        //    peek while lunch/AWOL days reach the cap (inner scroll beyond).
        // A LaunchedEffect below auto-expands when a NEW body card lands, so
        // added content (e.g. the active lunch-break card) presents itself
        // without the runner having to notice the handle.
        val peekHeight = maxHeight * 0.30f
        val expandedSheetHeight = (maxHeight - topReserve).coerceAtLeast(peekHeight)
        // Auto-expand on body-card arrival. Keyed on the card KEY SET — state
        // ticks inside a card (e.g. the lunch countdown) don't re-expand, and
        // removals never yank the sheet up. Starts empty so a card already
        // active on cold start (lunch mid-break) also presents expanded.
        var seenCardKeys by remember { mutableStateOf(emptySet<String>()) }
        LaunchedEffect(state.bodyCards.map { it.key }) {
            val keys = state.bodyCards.map { it.key }.toSet()
            val added = keys - seenCardKeys
            seenCardKeys = keys
            if (added.isNotEmpty()) runCatching { sheetState.expand() }
        }
        BottomSheetScaffold(
            modifier = Modifier.fillMaxSize(),
            scaffoldState = scaffoldState,
            sheetPeekHeight = peekHeight,
            sheetContainerColor = SnabbitTheme.colors.bgSecondary,
            sheetContentColor = SnabbitTheme.colors.textPrimary,
            sheetTonalElevation = 0.dp,
            sheetShadowElevation = 8.dp,
            containerColor = SnabbitTheme.colors.bgPrimary.copy(alpha = 0f),
            // ponytail: M3 DragHandle bakes 22.dp vertical padding via Surface;
            // can't shrink top without replacing the composable. Same 32x4 line,
            // 8.dp top instead of 22.dp.
            sheetDragHandle = {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = SnabbitTheme.spacing.componentPaddingSm, bottom = SnabbitTheme.spacing.componentPaddingSm),
                    contentAlignment = Alignment.Center,
                ) {
                    Box(
                        modifier = Modifier
                            .size(width = 32.dp, height = 4.dp)
                            .background(
                                color = SnabbitTheme.colors.textPrimary.copy(alpha = 0.18f),
                                shape = CircleShape,
                            ),
                    )
                }
            },
            sheetContent = {
                MapSheetContent(
                    state = state,
                    strings = strings,
                    onIntent = onIntent,
                    sheetHeight = expandedSheetHeight,
                    tieringSection = tieringSection,
                    tierPill = tierPill,
                )
            },
        ) { padding ->
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding)
                    .pointerInput(isRefreshing) {
                        detectVerticalDragGestures(
                            onDragEnd = {
                                if (dragDistance > refreshThresholdPx && !isRefreshing) {
                                    isRefreshing = true
                                    onIntent(HomeUiIntent.Load)
                                    scope.launch {
                                        delay(700)
                                        isRefreshing = false
                                    }
                                }
                                dragDistance = 0f
                            },
                            onDragCancel = { dragDistance = 0f },
                            onVerticalDrag = { _, dragAmount ->
                                if (!isRefreshing) {
                                    dragDistance = (dragDistance + dragAmount)
                                        .coerceAtLeast(0f)
                                }
                            },
                        )
                    },
            ) {
                // Camera centres on the runner's live GPS fix (state.mapCenter),
                // falling back to the Bangalore dev fixture until the first fix
                // resolves. Seva markers come from `GET /seva/nearby`.
                MapBackground(
                    modifier = Modifier.fillMaxSize(),
                    coordinates = state.mapCenter ?: MapBackgroundDefaultCoords,
                    // Nearest-first, capped — `SevaMarker` drops `distanceMeters`, so
                    // the sort/take has to happen here while the domain point still has it.
                    sevaMarkers = state.sevaPoints
                        .sortedBy { it.distanceMeters }
                        .take(MAX_SEVA_MARKERS)
                        .map {
                            SevaMarker(
                                id = it.id,
                                coords = MapCoords(it.lat, it.lng),
                                selected = it.id == state.sevaAnnouncement?.id,
                            )
                        },
                    onSevaClick = { onIntent(HomeUiIntent.TapSeva(it)) },
                    // "You are here" shows the runner's photo — same runners/me
                    // source the Profile header renders.
                    profilePhotoUrl = state.profilePhotoUrl,
                )
                // Top vignette — Figma 43:29600 (`gray-400 blur(50) opacity 70`).
                // Gives the pinned top nav a soft dark backdrop so the
                // bell/SOS/Saathi/coin badges read against any map tile.
                Box(
                    modifier = Modifier
                        .align(Alignment.TopCenter)
                        .fillMaxWidth()
                        .height(120.dp)
                        .background(
                            Brush.verticalGradient(
                                colors = listOf(
                                    SnabbitColorsLight.gray400.copy(alpha = 0.45f),
                                    SnabbitColorsLight.gray400.copy(alpha = 0f),
                                ),
                            ),
                        ),
                )
                // Bottom seam fade — Figma 43:29600 (`from-transparent
                // to-white, h-86px`). Softens the line where the map ends
                // and the bottom sheet begins. The Box is the Scaffold's
                // content area which already EXCLUDES the sheet, so its
                // bottom IS the sheet's top — aligning the gradient to
                // bottom-center anchors the white edge to the seam.
                Box(
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .fillMaxWidth()
                        .height(86.dp)
                        .background(
                            Brush.verticalGradient(
                                colors = listOf(
                                    SnabbitColorsLight.whiteDefault.copy(alpha = 0f),
                                    SnabbitColorsLight.whiteDefault,
                                ),
                            ),
                        ),
                )
                PinnedTopNav(
                    strings = strings,
                    onIntent = onIntent,
                    sosVisible = state.sosVisible,
                    coinsCount = state.coinsCount,
                    redCardsCount = state.redCardsCount,
                    coinsVisible = state.rewardsPillsVisible,
                    redCardVisible = state.redCardPillVisible,
                    tierPill = tierPill,
                )
                // Refresh spinner — pops under the nav while the read model
                // re-fetches. The drag detector above only fires post-
                // release, so there's no progressive drag indicator (a
                // ponytail concession; upgrade to a drag-driven indicator
                // when ShiftProjector exposes a real refresh signal).
                if (isRefreshing) {
                    Box(
                        modifier = Modifier
                            .align(Alignment.TopCenter)
                            .windowInsetsPadding(WindowInsets.statusBars)
                            .padding(top = 80.dp)
                            .size(40.dp)
                            .background(SnabbitTheme.colors.bgPrimary, CircleShape),
                        contentAlignment = Alignment.Center,
                    ) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(22.dp),
                            color = SnabbitTheme.colors.textPrimary,
                            strokeWidth = 2.dp,
                        )
                    }
                }
                // Map archetype doesn't go through SnabbitScreen — render
                // the snackbar host inline at the bottom.
                SnackbarHost(
                    hostState = snackbarHostState,
                    modifier = Modifier.align(Alignment.BottomCenter),
                )
            }
        }

        // Floating overlay — truly anchored to the bottom sheet's TOP edge,
        // tracking the sheet's live offset on drag. Lives OUTSIDE the
        // Scaffold (sibling overlay in the outer BoxWithConstraints) so
        // it can read `sheetState.requireOffset()` and reposition every
        // frame as the user drags the sheet up/down. Renders last in this
        // BoxWithConstraints → composes above the Scaffold in z-order.
        //
        // The seva helper card (Figma 969:56727) stacks ABOVE the base
        // [MapFloatingWidget] pill when [HomeUiState.sevaAnnouncement] is
        // non-null (auto-cleared after 5s by the VM).
        if (state.mapWidget != null || state.sevaAnnouncement != null) {
            val pillBottomGapPx = with(LocalDensity.current) { 12.dp.roundToPx() }
            val fallbackSheetTopPx = with(LocalDensity.current) {
                (maxHeight - peekHeight).roundToPx()
            }
            // Retain the last seva payload so AnimatedVisibility can render
            // content while sliding out after the VM clears the state.
            var lastSeva by remember { mutableStateOf<MapFloatingState.Seva?>(null) }
            state.sevaAnnouncement?.let { lastSeva = it }
            // Drives the helper card AND gates the base pill below it. Tracking the
            // transition (not the raw state) keeps the pill hidden for the whole
            // enter+exit cycle — gating on `sevaAnnouncement == null` would pop the
            // pill back in mid slide-out and flash it through the departing card.
            val sevaVisible = remember { MutableTransitionState(false) }
            sevaVisible.targetState = state.sevaAnnouncement != null
            val sevaGone = sevaVisible.isIdle && !sevaVisible.currentState
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = SnabbitTheme.spacing.componentPaddingMd)
                    // Feed the widget's real height back so the sheet's expand cap
                    // reserves exactly enough room for it (see topReserve above).
                    .onSizeChanged { floatingWidgetHeight = with(density) { it.height.toDp() } }
                    .layout { measurable, constraints ->
                        val placeable = measurable.measure(constraints)
                        // requireOffset throws before first layout — fall
                        // back to the peek-derived sheet-top so the first
                        // frame doesn't jump.
                        val sheetTopY = runCatching { sheetState.requireOffset() }
                            .getOrDefault(fallbackSheetTopPx.toFloat())
                        val pillTopY = (sheetTopY.toInt() - pillBottomGapPx - placeable.height)
                            .coerceAtLeast(0)
                        layout(placeable.width, placeable.height) {
                            placeable.place(0, pillTopY)
                        }
                    },
                contentAlignment = Alignment.BottomCenter,
            ) {
                // Z-stack: base pill draws first, seva helper card overlays
                // on top with a slide-in-from-bottom transition. Both are
                // bottom-anchored so the helper card lands exactly over the
                // pill when it settles. The pill is dropped entirely while the
                // helper card is on screen so it can't peek out behind it.
                state.mapWidget?.takeIf { sevaGone }?.let { widget ->
                    MapFloatingWidget(
                        state = widget,
                        strings = strings,
                        onIntent = onIntent,
                        inFlight = state.inFlight,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
                AnimatedVisibility(
                    // Helper card sits flush over the base pill (both
                    // bottom-anchored) — no peek strip / stacked-cards look.
                    visibleState = sevaVisible,
                    enter = slideInVertically(
                        animationSpec = tween(durationMillis = 260),
                        initialOffsetY = { fullHeight -> fullHeight },
                    ) + fadeIn(animationSpec = tween(durationMillis = 200)),
                    exit = slideOutVertically(
                        animationSpec = tween(durationMillis = 220),
                        targetOffsetY = { fullHeight -> fullHeight },
                    ) + fadeOut(animationSpec = tween(durationMillis = 180)),
                ) {
                    lastSeva?.let { seva ->
                        SevaHelperCard(
                            state = seva,
                            strings = strings,
                            onIntent = onIntent,
                            modifier = Modifier.fillMaxWidth(),
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun MapSheetContent(
    state: HomeUiState,
    strings: HomeStrings,
    onIntent: (HomeUiIntent) -> Unit,
    sheetHeight: Dp,
    tieringSection: @Composable () -> Unit = {},
    tierPill: HeaderNavPill? = null,
) {
    // [sheetHeight] is a CEILING (`heightIn(max)`), not a fixed size — the sheet
    // wraps its content, so a banner-only sheet peeks at its natural height
    // instead of a fixed 40% with dead space below. The cap still stops the
    // Expanded anchor rising into the top nav — see the `expandedSheetHeight`
    // note in MapLayout. `verticalScroll` lets the inner content scroll once
    // expanded; material3's NestedScrollConnection collapses the sheet on a
    // downward swipe at scroll-position 0.
    //
    // The floating widget lives OUTSIDE this sheet (rendered by MapLayout's
    // outer Box) — anchored at the sheet's top seam. Sheet content here is
    // the scrollable "More From Snabbit" only.
    // No `spacedBy` here — the AWOL slot is always composed and collapses to
    // zero height, and spacedBy still charges a full gap for zero-height
    // children (ECPO-833 #2: phantom space above "More From Snabbit"). Each
    // visible child carries its own bottom gap instead, so the first visible
    // content sits flush under the drag handle (Figma 222-50277).
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(max = sheetHeight)
            .verticalScroll(rememberScrollState())
            // Horizontal padding is owned by MoreFromSnabbitSection — adding it
            // here too doubled the gutter to 32dp (visible inset on the banner).
            // Bottom-only: the drag handle already gives a top gap; an extra
            // 16dp on top pushed the first card visibly off the design
            // (Figma 222-50277 — card sits flush under the handle).
            .padding(bottom = SnabbitTheme.spacing.componentPaddingMd),
    ) {
        // (AWOL no longer renders in the map sheet — it forces the Pink hero archetype.)
        // Body cards (e.g. the active-break LUNCH card) render above "More From
        // Snabbit" in the Map sheet. They own no horizontal gutter, so inset to
        // match MoreFromSnabbitSection's 16dp.
        state.bodyCards.forEach { card ->
            Box(
                modifier = Modifier
                    .padding(horizontal = SnabbitTheme.spacing.componentPaddingMd)
                    .padding(bottom = SnabbitTheme.spacing.layoutGapLg),
            ) {
                HomeCardRenderer(
                    card = card,
                    strings = strings,
                    onIntent = onIntent,
                    inFlight = state.inFlight,
                )
            }
        }
        // Tiering (Udaan banner / applicable nudge) above "More From Snabbit",
        // matching the Hero archetype and Flutter placement. Slot owns its
        // gutter + bottom gap; collapses to zero when there's nothing to show.
        tieringSection()
        MoreFromSnabbitSection(
            banners = state.moreFromSnabbit,
            strings = strings,
            onIntent = onIntent,
            isLoading = state.bannersLoading,
        )
        // Leave room for the gesture-nav inset at the bottom of the sheet.
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .windowInsetsPadding(WindowInsets.navigationBars),
        )
    }
}

/** Auto-dismiss window for the Saathi support-call feedback toast (matches `JobActionToast`). */
private const val SAATHI_TOAST_DURATION_MS = 4000L
