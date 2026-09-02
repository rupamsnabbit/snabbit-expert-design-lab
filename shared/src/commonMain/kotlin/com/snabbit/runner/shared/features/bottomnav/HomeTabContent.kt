package com.snabbit.runner.shared.features.bottomnav

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.core.navigation.NavigationController
import com.snabbit.runner.shared.features.awol.presentation.AwolEffect
import com.snabbit.runner.shared.features.awol.presentation.AwolHotspotDistanceTracker
import com.snabbit.runner.shared.features.awol.presentation.AwolSurface
import com.snabbit.runner.shared.features.awol.presentation.AwolViewModel
import com.snabbit.runner.shared.features.awol.domain.AwolStrings
import com.snabbit.runner.shared.features.awol.domain.localized
import com.snabbit.runner.shared.features.awol.presentation.ui.AwolHomeSection
import com.snabbit.runner.shared.features.gamification.data.GamificationProjector
import com.snabbit.runner.shared.features.gamification.domain.ctaOverridesForSheet
import com.snabbit.runner.shared.features.gamification.domain.filterForLifecycle
import com.snabbit.runner.shared.features.gamification.domain.model.CtaIds
import com.snabbit.runner.shared.features.gamification.domain.model.LifecycleActionTypes
import com.snabbit.runner.shared.features.gamification.domain.model.firstOfType
import com.snabbit.runner.shared.features.home.presentation.ui.sheets.ChangeAttendancePenalty
import com.snabbit.runner.shared.features.gamification.presentation.postaction.PostActionCoordinator
import com.snabbit.runner.shared.features.gamification.presentation.postaction.PostActionOverlayHost
import com.snabbit.runner.shared.features.home.presentation.HomeScreen
import com.snabbit.runner.shared.features.home.presentation.HomeUiEffect
import com.snabbit.runner.shared.features.home.presentation.HomeUiIntent
import com.snabbit.runner.shared.features.home.presentation.HomeViewModel
import com.snabbit.runner.shared.features.shift.presentation.login.ShiftLogin
import com.snabbit.runner.shared.features.tiering.presentation.ApplicableTieringNudge
import com.snabbit.runner.shared.features.tiering.presentation.SnabbitUdaanBanner
import com.snabbit.runner.shared.features.tiering.presentation.tierHeaderPill
import com.snabbit.runner.shared.features.tiering.presentation.contracts.TieringUiIntent
import com.snabbit.runner.shared.features.tiering.presentation.viewmodel.TieringViewModel
import org.koin.compose.viewmodel.koinViewModel
import org.koin.mp.KoinPlatform.getKoin

/**
 * The **Home tab's** content — the Koin-aware host around the pure-`commonMain`
 * [HomeScreen]. One host-only job lives here so `HomeScreen` stays DI-free
 * (previews/tests):
 *  - **ShiftLogin** is a full-screen page: on [HomeUiEffect.NavigateToShiftLogin]
 *    it pushes the `ShiftLogin` destination onto the [NavigationController]
 *    (rendered by `shiftLoginScreenModule`), instead of an in-place swap.
 *
 * (Emergency logout moved to the Profile tab — see `ProfileTabContent`.)
 *
 * [homeVm] is retained per nav-entry (registered via `viewModel { }`); this just
 * receives it, matching the LanguageScreen pattern.
 */
/** Dart `AadhaarReverificationPage.routeName` — the re-KYC page opened by the
 *  Aadhaar suspended-card variant. */
private const val ROUTE_AADHAAR_REVERIFICATION = "/aadhaar-reverification"

/** Dart `PayoutHome.routeName` — the earnings page for the suspended card's
 *  "Go to Earnings" CTA (non-rate-card-v2 case). */
private const val ROUTE_PAYOUT_HOME = "/payout-home"

/** Dart `AppWebViewPage.routeName` — host-backed webview shell (same route the
 *  coins pill uses); Dart builds the URL from the `webviewPath` arg. */
private const val ROUTE_APP_WEB_VIEW = "/app-web-view"

/** Dart `WebviewRoutes.payoutsMonthlySummary` — the rate-card-v2 earnings page
 *  opened by "Go to Earnings" when `isRateCardV2Effective` (Dart parity). */
private const val WEBVIEW_EARNINGS_MONTHLY_SUMMARY = "v1/payouts/monthly-summary"

/** Dart `WebviewRoutes.payoutsShiftEndSummary` — the shift-end earnings summary
 *  opened after an attendance-chained shift logout (rate-card-v2 only). */
private const val WEBVIEW_SHIFT_END_SUMMARY = "v1/payouts/shift-end-summary"

/** Recreate coordinates for the keep-host handoffs — rebuild the Home shell on
 *  the Home tab (re-projects the suspended card) if the OS reclaims the host. */
private const val RECREATE_HOME_SHELL = "home_shell"
private val recreateHomeTab = mapOf("initialTab" to "Home")

@Composable
fun HomeTabContent(
    homeVm: HomeViewModel = koinViewModel(),
    tieringVm: TieringViewModel = koinViewModel(),
) {
    val koin = getKoin()
    val controller = koin.get<NavigationController>()
    // Post-action overlay coordinator so the reward/penalty popup survives an
    // action's slot dismissing (e.g. change-attendance).
    val coordinator = koin.get<PostActionCoordinator>()

    // First load is fired from HomeViewModel.init (the VM is retained for the
    // shell's whole lifetime). We deliberately do NOT re-fetch on tab re-entry:
    // the tab host disposes the non-current subtree, so a LaunchedEffect(Unit)
    // here would re-fire the whole fan-out every Home↔other-tab toggle — but
    // MQTT keeps current_state fresh, the disconnected fallback poll and Dart's
    // resumed-lifecycle catch-up cover the rest, and switching tabs never
    // backgrounds the process. Pull-to-refresh (HomeUiIntent.Load) still forces it.

    LaunchedEffect(homeVm) {
        homeVm.effects.collect { effect ->
            when (effect) {
                HomeUiEffect.NavigateToShiftLogin -> controller.navigate(ShiftLogin)
                is HomeUiEffect.ShowSnackbar -> Unit // HomeScreen collects its own snackbar.
                is HomeUiEffect.OpenDirections -> Unit // HomeScreen opens the maps URI itself.
                // Suspended-card CTAs bridge to Dart pages (none migrated to CMP).
                // Keep the host alive so system-back returns to the suspended Home
                // takeover instead of finishing it — same reordering round trip the
                // coins pill uses (HomeModule). recreateKey/args rebuild the Home shell
                // (which re-projects the suspended card from RUNNER_SUSPENDED) if the OS
                // reclaims the backgrounded host. All routes are in Dart `appRoutes`.
                HomeUiEffect.NavigateToAadhaarReKyc ->
                    controller.requestFlutterRouteKeepingHost(
                        route = ROUTE_AADHAAR_REVERIFICATION,
                        recreateKey = RECREATE_HOME_SHELL,
                        recreateArgs = recreateHomeTab,
                    )
                // Dart `navigateToEarningsPage`: rate-card-v2 runners open the
                // monthly-summary webview (Dart builds the URL from `webviewPath`,
                // same as the coins pill); everyone else lands on native Payout Home.
                is HomeUiEffect.NavigateToEarnings ->
                    if (effect.rateCardV2Effective) {
                        controller.requestFlutterRouteKeepingHost(
                            route = ROUTE_APP_WEB_VIEW,
                            args = mapOf(
                                "webviewPath" to WEBVIEW_EARNINGS_MONTHLY_SUMMARY,
                                "title" to "Earnings",
                            ),
                            recreateKey = RECREATE_HOME_SHELL,
                            recreateArgs = recreateHomeTab,
                        )
                    } else {
                        controller.requestFlutterRouteKeepingHost(
                            route = ROUTE_PAYOUT_HOME,
                            recreateKey = RECREATE_HOME_SHELL,
                            recreateArgs = recreateHomeTab,
                        )
                    }
                // Post-logout shift-end earnings (Dart PA_BEFORE_LOGOUT's "View
                // Today's Earnings", v2-only). Same keep-host webview bridge the
                // suspended-card earnings uses, pointed at the shift-end summary.
                HomeUiEffect.NavigateToShiftEndEarnings ->
                    controller.requestFlutterRouteKeepingHost(
                        route = ROUTE_APP_WEB_VIEW,
                        args = mapOf(
                            "webviewPath" to WEBVIEW_SHIFT_END_SUMMARY,
                            "title" to "Today's Earnings",
                        ),
                        recreateKey = RECREATE_HOME_SHELL,
                        recreateArgs = recreateHomeTab,
                    )
            }
        }
    }

    // AWOL coordinator (process-lived Koin single, shared with the overlay).
    // Hoisted here so both the `awolCard` slot and the `awolActive` sheet-focus
    // signal read the same instance. `awolActive` is true for ANY in-app AWOL
    // condition — breach AND re-entered alike (both route HOME_CARD) — so the
    // map sheet lifts to focus the card the same way for each.
    val awolVm = remember { koin.get<AwolViewModel>() }
    val awolFlags by awolVm.flags.collectAsState()
    val awolState by awolVm.uiState.collectAsState()
    // DERIVED, not read straight off the collected state: `AwolUiState` re-emits once a
    // second while a breach countdown runs, so reading it in this (host-root) scope
    // re-executed the whole tab every second — the Koin lookups, the gamification
    // projection, the nudge scan — to produce an identical boolean. `derivedStateOf`
    // keeps this scope subscribed to the BOOLEAN only; the countdown itself still
    // recomposes where it renders (AwolHomeSection's own scope).
    val awolActive by remember(awolVm) {
        derivedStateOf { awolFlags.homeCardEnabled && awolState.surface == AwolSurface.HOME_CARD }
    }

    // Decoded gamification read model, shared across Home's gamified surfaces:
    // the emergency-logout Logout CTA badge and the change-attendance penalty
    // red-card cluster. Hoisted here (host scope) so both read one collection.
    val gamification = koin.get<GamificationProjector>()
    val gamState by gamification.state.collectAsState()
    // FALSE_ATTENDANCE penalty chrome for ChangeAttendanceConfirm, data-driven
    // like Dart's `showPenaltyChrome = hasNudges` (job_login.dart:317): present
    // only when a FALSE_ATTENDANCE sheet warning exists. Count + button badges
    // come from its cta overrides (Dart `ctaMap[mark_absent].redCards ?? 3` for
    // the cluster; mark_absent on Absent, go_back on Present).
    val changeAttendancePenalty = gamState.sheetWarnings
        .filterForLifecycle(LifecycleActionTypes.FALSE_ATTENDANCE)
        .takeIf { it.isNotEmpty() }
        ?.ctaOverridesForSheet()
        ?.let { ctaMap ->
            ChangeAttendancePenalty(
                redCardCount = ctaMap[CtaIds.MARK_ABSENT]?.redCards ?: 3,
                absentCta = ctaMap[CtaIds.MARK_ABSENT],
                presentCta = ctaMap[CtaIds.GO_BACK],
            )
        }

    // Login pre-action nudge → strip docked under the Present card (Figma DS
    // 87-25340). Parsed already; just picked out by lifecycle here.
    //
    // EARLY_LOGIN covers the whole pre-login window, opportunity and risk alike:
    // the BE emits one nudge stepped by minutes-to-shift-start, flipping from an
    // `opportunity` coin nudge to a `risk` red-card one at T-0 (maestro-core
    // `_get_early_login_nudges`). LATE_LOGIN exists as a red-card *rule* name
    // there, never as a `lifecycle_action_type` — don't match on it.
    val loginNudge = gamState.nudges.firstOfType(LifecycleActionTypes.EARLY_LOGIN)

    // Tiering surfaces (mount-none until now). The VM folds the Dart-fed
    // `current_state.tier_nudge` + `runners/me` slice into `TieringUiState`;
    // all visibility (ECPO-924 intro gate) lives there. The banner and the
    // nudge are mutually exclusive — `showUdaanBanner = !hasViewedIntro`,
    // `homeNudge` is null until the intro is viewed — so at most one renders.
    val tierState by tieringVm.uiState.collectAsState()
    // App-bar tier badge — shown (in place of the gold-coins pill) on the full date-based
    // `shouldShowTiering` gate (TieringUiState.tierBadge, Flutter TierBadgeV2 — deliberately
    // NOT the profile card's tier-identity gate, so it can lag the card until the effective
    // date); tap → tiers "Levels Home".
    val tierPill = tierState.tierBadge?.tier?.let { tier ->
        tierHeaderPill(tier) { tieringVm.onIntent(TieringUiIntent.TierBadgeClicked) }
    }

    Box {
        HomeScreen(
            viewModel = homeVm,
            awolActive = awolActive,
            changeAttendancePenalty = changeAttendancePenalty,
            loginNudge = loginNudge,
            tierPill = tierPill,
            tieringSection = {
                if (tierState.showUdaanBanner || tierState.homeNudge != null) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            // Match the DS content gutter (same inset the map
                            // sheet's body cards use) + a 32dp gap to the strip
                            // below; both owned here so an empty slot adds nothing.
                            .padding(horizontal = SnabbitTheme.spacing.componentPaddingMd)
                            .padding(bottom = SnabbitTheme.spacing.layoutGapLg),
                        // ≥16dp between the Udaan banner and the nudge (they'd otherwise
                        // sit flush); banner-alone still keeps the 32dp bottom gap above.
                        verticalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.`5`),
                    ) {
                        SnabbitUdaanBanner(
                            visible = tierState.showUdaanBanner,
                            onShown = { tieringVm.onIntent(TieringUiIntent.BannerShown(showHeaderImage = true)) },
                            onAccept = { tieringVm.onIntent(TieringUiIntent.BannerClicked(showHeaderImage = true)) },
                        )
                        ApplicableTieringNudge(
                            content = tierState.homeNudge,
                            onShown = { tieringVm.onIntent(TieringUiIntent.NudgeShown) },
                            onClick = { tieringVm.onIntent(TieringUiIntent.NudgeClicked) },
                        )
                    }
                }
            },
            awolCard = {
                // Mount the shared HOME_CARD surface only when the
                // `expert_enable_awol_v2_home_card` kill-switch is on (pushed into the
                // VM's flags from Dart RC); off = no card, no distance tracking.
                if (awolFlags.homeCardEnabled) {
                    // Distance tracker rides this slot's scope (computed only while the
                    // tile is composed); torn down when the Home tab leaves composition.
                    // It reads Home's ALREADY-RUNNING fix rather than opening a second
                    // FusedLocationProvider stream for the same screen — same accuracy
                    // and cadence, one GPS request instead of two.
                    val awolScope = rememberCoroutineScope()
                    val tracker = remember {
                        AwolHotspotDistanceTracker(
                            runnerLocation = homeVm.runnerLocation,
                            uiState = awolVm.uiState,
                            scope = awolScope,
                        ).also { it.start() }
                    }
                    val uriHandler = LocalUriHandler.current
                    LaunchedEffect(awolVm) {
                        awolVm.effects.collect { effect ->
                            // The overlay surface collects the same broadcast flow; only
                            // the on-screen HOME_CARD acts on the Show-Directions CTA.
                            if (awolVm.uiState.value.surface != AwolSurface.HOME_CARD) return@collect
                            when (effect) {
                                is AwolEffect.OpenDirections -> uriHandler.openUri(
                                    "https://www.google.com/maps/dir/?api=1" +
                                        "&destination=${effect.latitude},${effect.longitude}" +
                                        "&travelmode=driving",
                                )
                            }
                        }
                    }
                    AwolHomeSection(
                        viewModel = awolVm,
                        distanceText = tracker.distanceText,
                        strings = AwolStrings().localized(koin.get()),
                    )
                }
            },
        )

        // Mount-once post-action overlay (commonMain — no Android nav activity
        // needed). Reward/penalty → popup; waived → home's WaiverSheet, then
        // dismiss the coordinator to resume the suspended action caller.
        PostActionOverlayHost(
            coordinator = coordinator,
            onWaived = { outcome ->
                homeVm.onIntent(HomeUiIntent.ShowRedCardsWaived(outcome.redCards))
                coordinator.dismiss()
            },
        )
    }
}
