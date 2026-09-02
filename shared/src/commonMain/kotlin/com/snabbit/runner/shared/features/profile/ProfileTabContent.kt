package com.snabbit.runner.shared.features.profile

import androidx.compose.foundation.layout.Box
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import com.snabbit.design.organisms.SnabbitBottomSheet
import com.snabbit.runner.shared.core.analytics.ErrorAnalytics
import com.snabbit.runner.shared.core.navigation.ShellLoanRequest
import com.snabbit.runner.shared.core.network.NetworkConfigStore
import com.snabbit.runner.shared.core.DebugLogGate
import com.snabbit.runner.shared.core.realtime.RealtimeDiagnostics
import com.snabbit.runner.shared.core.realtime.RealtimeStatus
import com.snabbit.runner.shared.core.runnerstate.RunnerStateStore
import com.snabbit.runner.shared.features.gamification.data.GamificationProjector
import com.snabbit.runner.shared.features.gamification.domain.model.CtaIds
import com.snabbit.runner.shared.features.gamification.presentation.postaction.PostActionCoordinator
import com.snabbit.runner.shared.features.gamification.presentation.postaction.PostActionOverlayHost
import com.snabbit.runner.shared.features.home.presentation.rememberHomeStrings
import com.snabbit.runner.shared.features.home.presentation.ui.sheets.WaiverSheet
import com.snabbit.runner.shared.features.periodleave.domain.repository.PeriodLeaveRepository
import com.snabbit.runner.shared.features.profile.ui.ProfileFooterData
import com.snabbit.runner.shared.features.shift.core.domain.repository.ShiftRepository
import com.snabbit.runner.shared.features.shift.presentation.emergencylogout.EmergencyLogoutAnalytics
import com.snabbit.runner.shared.features.shift.presentation.emergencylogout.EmergencyLogoutScreen
import com.snabbit.runner.shared.features.shift.presentation.emergencylogout.EmergencyLogoutViewModel
import com.snabbit.runner.shared.features.tiering.presentation.SnabbitUdaanBanner
import com.snabbit.runner.shared.features.tiering.presentation.SnabbitUdaanPlayVideoRow
import com.snabbit.runner.shared.features.tiering.presentation.contracts.TieringUiIntent
import com.snabbit.runner.shared.features.tiering.presentation.viewmodel.TieringViewModel
import kotlinx.coroutines.launch
import org.koin.compose.viewmodel.koinViewModel
import org.koin.mp.KoinPlatform.getKoin

/**
 * Debug label for the realtime engine status (non-prod Profile footer). Conveys
 * whether MQTT is live or the current_state fallback is the data path.
 */
private fun RealtimeStatus.debugLabel(): String = when (this) {
    RealtimeStatus.Idle -> "Idle"
    RealtimeStatus.Connecting -> "Connecting…"
    RealtimeStatus.Connected -> "Connected (MQTT)"
    RealtimeStatus.Reconnecting -> "Reconnecting…"
    RealtimeStatus.Degraded -> "Degraded (current_state polling)"
    RealtimeStatus.PollOnly -> "Poll-only (current_state)"
    RealtimeStatus.Offline -> "Offline"
    is RealtimeStatus.Stopped -> "Stopped"
}

/**
 * The **Profile tab's** content — the Koin-aware host around the pure-`commonMain`
 * [ProfileScreen]. Mirrors [com.snabbit.runner.shared.features.bottomnav.HomeTabContent]:
 * [ProfileViewModel] is retained per nav-entry (registered via `viewModel { }` in
 * `profileModule`) and resolved here through [koinViewModel]; the footer (app version +
 * non-prod endpoint) is read from the bridged [NetworkConfigStore]. Rendered by the
 * bottom-nav shell for `NavTab.Profile`.
 *
 * Host-only job: **EmergencyLogout** — the "Emergency logout" menu tile opens a modal
 * flow that owns its own VM (needs Koin/platform deps), so it's supplied to
 * `ProfileScreen` as a slot built from Koin here (was the Home FAB flow before).
 *
 * [onSwitchToHome] is invoked once a SUCCESSFUL emergency logout fully completes
 * (sheets closed, waiver acknowledged) — the shell switches to the Home tab so
 * the provisional-attendance sheet auto-mounting there (`PA_BEFORE_LOGOUT`
 * envelope) is actually seen (ECPO-843; Dart parity — the old flow lived on
 * home, where the PA sheet appeared right after TakeCare). A cancelled /
 * dismissed flow never navigates.
 */
@Composable
fun ProfileTabContent(
    viewModel: ProfileViewModel = koinViewModel(),
    tieringViewModel: TieringViewModel = koinViewModel(),
    onSwitchToHome: () -> Unit = {},
) {
    val koin = getKoin()
    // Tiering surface on the profile card — the tier row (TieringUiState.profileTierCard, now gated
    // on TIER IDENTITY: any new-scheme tier, independent of the effective date — Flutter
    // view_tier / expert_info `!isLegacyTier`). Non-null → the header renders the per-tier
    // "level" card; "View level" opens the tiers webview.
    val tierState by tieringViewModel.uiState.collectAsState()
    val tierRow = tierState.profileTierCard
    val strings = remember { ProfileStrings().localized(koin.get()) }
    val configStore = remember { getKoin().get<NetworkConfigStore>() }
    // Debug realtime diagnostics (footer): live MQTT status + endpoint.
    val realtimeDiagnostics = remember { getKoin().get<RealtimeDiagnostics>() }
    val engineStatus by realtimeDiagnostics.status.collectAsState()
    // Reuses the process-wide gate armed by KmpBootstrap from the host manifest's
    // `debuggable` flag — the same signal as BuildConfig.DEBUG, already available to
    // commonMain. Deliberately NOT a second mechanism: it defaults to false, so a
    // process whose bootstrap never ran stays quiet rather than leaking diagnostics.
    val isDebugBuild = remember { DebugLogGate.isEnabled }
    // Footer values from the bridged network config. Shown on a DEBUG BUILD REGARDLESS
    // OF ENVIRONMENT, or on any non-prod build. The env gate alone was wrong: a debug
    // build pointed at production hid the realtime line entirely, which is precisely
    // when "is MQTT connected, or am I silently on current_state polling?" matters —
    // and the endpoint rides along so the answer is never ambiguous about WHICH broker.
    // Release + prod still shows neither, so nothing leaks to runners.
    val footer = configStore.snapshot()?.let {
        val showDiagnostics = isDebugBuild || !it.isProd
        ProfileFooterData(
            appVersion = it.appVersion,
            endpoint = if (showDiagnostics) it.baseUrl else null,
            realtimeStatus = if (showDiagnostics) engineStatus.debugLabel() else null,
        )
    }

    // Post-action overlay coordinator so the emergency-logout reward/penalty popup
    // survives the sheet dismissing.
    val coordinator = koin.get<PostActionCoordinator>()
    val emergencyLogoutAnalytics = koin.get<EmergencyLogoutAnalytics>()
    val hostScope = rememberCoroutineScope()
    // Feature #4: arm the engine's timed current_state fallback on emergency-logout
    // success so a missed logout transition self-heals if MQTT doesn't deliver it.
    val runnerStateStore = koin.get<RunnerStateStore>()
    // Decoded gamification read model — the emergency-logout Logout CTA badge +
    // consequence-card count come from its cta_overrides[logout].
    val gamification = koin.get<GamificationProjector>()
    val gamState by gamification.state.collectAsState()

    // Deep-link loan request (MQTT-cohort): the bridge asks the running shell to open the
    // native loan sheet; the shell switches to this tab, and here we dispatch ShowLoanSheet
    // and consume the request. Keyed on the flag so it fires once per request (consume flips
    // it back to false); parity with tapping the "Get loan" tile (ProfileMenu).
    val loanRequest = remember { koin.get<ShellLoanRequest>() }
    val loanPending by loanRequest.pending.collectAsState()
    LaunchedEffect(loanPending) {
        if (loanPending) {
            viewModel.onIntent(ProfileUiIntent.ShowLoanSheet)
            loanRequest.consume()
        }
    }

    // ECPO-843: after a SUCCESSFUL emergency logout the PA sheet auto-mounts on
    // the HOME tab (PA_BEFORE_LOGOUT envelope) — track success + flow-completion
    // so we can hand the runner over there once every sheet here is done.
    var emergencyLoggedOut by remember { mutableStateOf(false) }
    var emergencyFlowDone by remember { mutableStateOf(false) }

    Box {
        ProfileScreen(
            viewModel = viewModel,
            strings = strings,
            footer = footer,
            tier = tierRow?.tier,
            onTierClick = { tieringViewModel.onIntent(TieringUiIntent.ProfileTierClicked) },
            onTierShown = { tieringViewModel.onIntent(TieringUiIntent.ProfileTierShown) },
            // Tiering live (effective date reached) → the menu's generic Insurance tile splits
            // into Accident + Health (Flutter drawer parity).
            tieringEnabled = tierState.isTieringEnabled,
            // Udaan surface below the profile card: pre-intro the intro banner
            // (`showUdaanBanner`), then once the intro is viewed the "Play video" row
            // (`showUdaanPlayVideoRow`) that re-opens it. The two are mutually exclusive
            // on `hasViewedIntro`, so this renders at most one; null → nothing (the
            // LazyColumn adds no phantom item/gap).
            udaanSurface = when {
                tierState.showUdaanBanner -> {
                    {
                        SnabbitUdaanBanner(
                            visible = true,
                            onShown = { tieringViewModel.onIntent(TieringUiIntent.BannerShown(showHeaderImage = true)) },
                            onAccept = { tieringViewModel.onIntent(TieringUiIntent.BannerClicked(showHeaderImage = true)) },
                        )
                    }
                }
                tierState.showUdaanPlayVideoRow -> {
                    {
                        SnabbitUdaanPlayVideoRow(
                            visible = true,
                            onPlayVideo = { tieringViewModel.onIntent(TieringUiIntent.PlayVideoClicked) },
                        )
                    }
                }
                else -> null
            },
            emergencyLogoutSheet = { onDismiss ->
                // Reconstructed each time the flow opens (remember re-inits when the
                // slot re-enters composition) so availability re-fetches every open.
                // Rides a scope tied to the slot, so it dies when the flow closes.
                val scope = rememberCoroutineScope()
                val vm = remember {
                    EmergencyLogoutViewModel(
                        shiftRepository = koin.get<ShiftRepository>(),
                        periodLeaveRepository = koin.get<PeriodLeaveRepository>(),
                        analytics = koin.get<EmergencyLogoutAnalytics>(),
                        errorAnalytics = koin.get<ErrorAnalytics>(),
                        scope = scope,
                        // WS5 feature #4: the post-logout envelope normally arrives via
                        // the MQTT snapshot, but arm the timed current_state fallback so a
                        // missed logout transition self-heals. (Distinct from onPostAction
                        // below, which presents the gamification reward popup.)
                        onEmergencyLoggedOut = {
                            runnerStateStore.onPostAction("emergency_logout")
                            emergencyLoggedOut = true
                        },
                        // Show the reward/penalty popup on a host scope so it
                        // outlives this sheet's dismissal.
                        onPostAction = { outcome -> hostScope.launch { coordinator.show(outcome) } },
                    )
                }
                // Real cta_overrides[logout] from the decoded sheet_warnings — drives
                // both the consequence-card count and the Logout badge. The
                // "Lose ₹X" tile comes off the availability payload inside the
                // screen itself (ECPO-753).
                EmergencyLogoutScreen(
                    viewModel = vm,
                    onFinish = {
                        onDismiss()
                        // Only a flow that actually logged out hands over to
                        // Home (ECPO-843) — cancel/back stays on Profile.
                        if (emergencyLoggedOut) emergencyFlowDone = true
                    },
                    logoutCta = gamState.ctaOverride(CtaIds.LOGOUT),
                )
            },
        )

        // Mount-once post-action overlay for the emergency-logout outcome popup.
        // Waived outcomes (a period-leave logout waives the red card) get the
        // same WaiverSheet treatment as HomeTabContent — this host used to
        // dismiss them silently, so the waived red-card outcome was never
        // visible after the flow moved Home → Profile (ECPO-753 follow-up).
        var waivedRedCards by remember { mutableStateOf<Int?>(null) }
        PostActionOverlayHost(
            coordinator = coordinator,
            onWaived = { outcome ->
                waivedRedCards = outcome.redCards
                coordinator.dismiss()
            },
        )
        val homeStrings = rememberHomeStrings()
        SnabbitBottomSheet(
            visible = waivedRedCards != null,
            onDismissRequest = { waivedRedCards = null },
            contentDescription = homeStrings.sheetCloseContentDescription,
        ) {
            WaiverSheet(
                redCardCount = waivedRedCards ?: 0,
                strings = homeStrings,
                onAcknowledge = {
                    emergencyLogoutAnalytics.waiverAcknowledged()
                    waivedRedCards = null
                },
            )
        }

        // ECPO-843: hand over to the Home tab once the successful-logout flow is
        // fully done (sheets closed AND any waiver acknowledged) — the
        // provisional-attendance sheet auto-mounts there off the
        // PA_BEFORE_LOGOUT envelope and would otherwise go unseen while the
        // runner sits on Profile. If the waived outcome instead lands after
        // this switch, Home's own overlay host picks it up from the
        // process-lived coordinator — visible either way.
        LaunchedEffect(emergencyFlowDone, waivedRedCards) {
            if (emergencyFlowDone && waivedRedCards == null) {
                emergencyFlowDone = false
                emergencyLoggedOut = false
                onSwitchToHome()
            }
        }
    }
}
