package com.snabbit.runner.shared.features.bottomnav

import androidx.compose.foundation.layout.Column
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.snabbit.runner.shared.core.camera.ui.OnAppResumed
import com.snabbit.runner.shared.core.connectivity.ConnectivityStatus
import com.snabbit.runner.shared.core.connectivity.NetworkMonitor
import com.snabbit.runner.shared.core.designsystem.components.SnabbitBottomTabBar
import com.snabbit.runner.shared.core.designsystem.components.SnabbitTabSpec
import com.snabbit.runner.shared.core.navigation.LocalRootShellExit
import com.snabbit.runner.shared.core.navigation.NavigationController
import com.snabbit.runner.shared.core.navigation.ShellLoanRequest
import com.snabbit.runner.shared.core.navigation.di.nativeScreen
import com.snabbit.runner.shared.core.analytics.AnalyticsTracker
import com.snabbit.runner.shared.core.navigation.tabs.TabNavigator
import com.snabbit.runner.shared.core.navigation.tabs.TabNavigatorState
import com.snabbit.runner.shared.core.navigation.tabs.TabNavigatorStateHolder
import com.snabbit.runner.shared.core.remoteconfig.RemoteConfigGateway
import com.snabbit.runner.shared.core.runnerstate.RunnerStateStore
import com.snabbit.runner.shared.features.autoot.presentation.AutoOtOverlay
import com.snabbit.runner.shared.features.comingsoon.ComingSoonScreen
import com.snabbit.runner.shared.features.home.banners.data.HomeBannersStore
import com.snabbit.runner.shared.features.kavach.sos.ui.AppSosHost
import com.snabbit.runner.shared.features.profile.FlutterRoute
import com.snabbit.runner.shared.features.profile.ProfileBridgeState
import com.snabbit.runner.shared.features.profile.ProfileFlutterRoutes
import com.snabbit.runner.shared.features.profile.ProfileRouteDecider
import com.snabbit.runner.shared.features.profile.ProfileTabContent
import com.snabbit.runner.shared.features.profile.RunnerProfileStore
import com.snabbit.runner.shared.resources.Res
import com.snabbit.runner.shared.resources.tab_earnings_active
import com.snabbit.runner.shared.resources.tab_earnings_inactive
import com.snabbit.runner.shared.resources.tab_home_active
import com.snabbit.runner.shared.resources.tab_home_inactive
import com.snabbit.runner.shared.resources.tab_notifications_dot
import com.snabbit.runner.shared.resources.tab_notifications_inactive
import com.snabbit.runner.shared.resources.tab_profile_active
import com.snabbit.runner.shared.resources.tab_profile_inactive
import com.snabbit.runner.shared.resources.tab_refer_active
import com.snabbit.runner.shared.resources.tab_refer_inactive
import com.snabbit.runner.shared.ui.components.SnabbitConnectivityBanner
import kotlinx.coroutines.launch
import org.koin.core.module.Module
import org.koin.dsl.module
import org.koin.mp.KoinPlatform.getKoin

private const val RC_NOTIFICATIONS_TAB = "expert_is_notifications_tab_enabled"

private fun tabSpec(tab: NavTab, hasUnreadNotifications: Boolean): SnabbitTabSpec = when (tab) {
    NavTab.Home ->
        SnabbitTabSpec(Res.drawable.tab_home_active, Res.drawable.tab_home_inactive, "Home")
    NavTab.Earnings ->
        SnabbitTabSpec(Res.drawable.tab_earnings_active, Res.drawable.tab_earnings_inactive, "Earnings")
    NavTab.Refer ->
        SnabbitTabSpec(Res.drawable.tab_refer_active, Res.drawable.tab_refer_inactive, "Refer")
    NavTab.Notifications -> {
        val icon = if (hasUnreadNotifications) {
            Res.drawable.tab_notifications_dot
        } else {
            Res.drawable.tab_notifications_inactive
        }
        SnabbitTabSpec(icon, icon, "Updates")
    }
    NavTab.Profile ->
        SnabbitTabSpec(Res.drawable.tab_profile_active, Res.drawable.tab_profile_inactive, "Profile")
}

/**
 * The `current_state` widget name shown while the runner is suspended (Flutter
 * `widgets_util.dart` → `RunnerSuspended`, rendered with `showDrawer: false`). The shell
 * hides the Profile tab while this is the active widget.
 */
private const val WIDGET_RUNNER_SUSPENDED = "RUNNER_SUSPENDED"

/**
 * Registration of the bottom-nav shell ([BottomNavHost]) — pure `commonMain`, so it is
 * iOS-registrable. The `nativeScreen` DSL and Nav3 are multiplatform (cf. `shiftLoginScreenModule`);
 * the two former androidMain blockers are now behind seams:
 *  - exit-app back reads [LocalRootShellExit] (the host provides `finishAffinity()`; default no-op);
 *  - [ActiveJobOverlay]'s TTS + back use `rememberJobTtsController` + the multiplatform
 *    `BackHandler`, so no `LocalContext` / `AndroidTtsController` leaks here.
 * Registered once at bootstrap (see `KmpBootstrap`), so `:app` never registers screens.
 *
 * [HomeViewModel] is retained per nav-entry via `viewModel { }` (it owns its
 * `viewModelScope`); [HomeTabContent] is pure `commonMain` and just receives it.
 */
val bottomNavScreenModule: Module = module {
    nativeScreen<BottomNavHost> { dest ->
        // Start-tab back exits the app. The host injects the platform action via
        // LocalRootShellExit (NavigationHostActivity provides finishAffinity()); the default
        // no-op keeps a non-root or not-yet-provided host from crashing. Read here (instead of
        // reaching a ComponentActivity) so the shell registration stays commonMain.
        val onExit = LocalRootShellExit.current
        val start = remember(dest.initialTab) { startNavTab(dest.initialTab) }
        // Hold the tab state in an entry-scoped ViewModel (not a plain remember) so the
        // selected tab survives the shell entry leaving composition when a native
        // destination — e.g. the Language screen — is pushed on top of it. A plain
        // remember is disposed there and re-seeds to the start tab (Home) on return.
        val state = viewModel<TabNavigatorStateHolder<NavTab>> {
            TabNavigatorStateHolder(TabNavigatorState(tabs = NavTab.entries, startTab = start))
        }.state
        // Hide the Profile tab while the runner is suspended — parity with Flutter's
        // `showDrawer: false` on the RUNNER_SUSPENDED current_state widget. Reactive via
        // RunnerStateStore: on unsuspend the home's fetchDataNow() re-pushes current_state,
        // the widget leaves RUNNER_SUSPENDED, and the tab returns automatically.
        val runnerStateStore = remember { getKoin().get<RunnerStateStore>() }
        val runnerState by runnerStateStore.state.collectAsState()
        val isSuspended = runnerState?.widgetName == WIDGET_RUNNER_SUSPENDED
        // Don't leave the runner parked on the (now hidden) Profile tab.
        LaunchedEffect(isSuspended) {
            if (isSuspended && state.currentTab == NavTab.Profile) state.switchTab(NavTab.Home)
        }
        // Deep-link loan request (MQTT-cohort only): the bridge sets this on the running shell
        // to open the native Profile-tab loan sheet. Switch to Profile so ProfileTabContent
        // composes and consumes it (dispatching ShowLoanSheet). If the runner is suspended the
        // Profile tab is hidden, so drop the request here rather than let it dangle and pop the
        // sheet later on unsuspend.
        val loanRequest = remember { getKoin().get<ShellLoanRequest>() }
        val loanPending by loanRequest.pending.collectAsState()
        LaunchedEffect(loanPending, isSuspended) {
            if (!loanPending) return@LaunchedEffect
            if (isSuspended) loanRequest.consume() else state.switchTab(NavTab.Profile)
        }
        // Earnings/Refer tabs open an existing Flutter page (keep-host) rather than native
        // content. The route is decided from the bridge-fed profile (rate-card v2) + Remote
        // Config, reusing the same deciders as the Profile menu tiles (drawer parity).
        val nav = remember { getKoin().get<NavigationController>() }
        val analytics = remember { getKoin().get<AnalyticsTracker>() }
        val remoteConfig = remember { getKoin().get<RemoteConfigGateway>() }
        val profileStore = remember { getKoin().get<RunnerProfileStore>() }
        // Feature #2: real device connectivity for the inline offline strip below.
        val networkMonitor = remember { getKoin().get<NetworkMonitor>() }
        val connectivity by networkMonitor.status.collectAsState()
        // Seed the bridge-fed profile on shell launch if Dart hasn't pushed yet (warm start,
        // still Loading), so the Profile tab + the Earnings tab's v2 gating have data. One
        // call (the store collapses concurrent requests; skipped once content is present).
        LaunchedEffect(Unit) {
            if (profileStore.state.value is ProfileBridgeState.Loading) profileStore.requestRefresh()
        }
        // Badge count rides the same `/me/home_banners` call Home uses. Owned here,
        // not in HomeViewModel: the dot shows on every tab, and HomeViewModel is
        // built lazily on first Home composition — a launch onto Profile would
        // otherwise never fetch it.
        val homeBanners = remember { getKoin().get<HomeBannersStore>() }
        val homeBannersState by homeBanners.state.collectAsStateWithLifecycle()
        val badgeScope = rememberCoroutineScope()
        // Absorb an accidental double-tap on Earnings/Refer before the Flutter surface covers
        // the bar. The keep-host round trip backgrounds (not disposes) this composition, so a
        // plain remember flag never clears on its own — clear it when the host RESUMES (returns
        // from the Flutter page), so the NEXT tap works. Fires only on return, never during the
        // launch (the host is pausing then), so the double-tap window stays guarded.
        val launching = remember { mutableStateOf(false) }
        OnAppResumed {
            launching.value = false
            // The only trigger this adds to `/me/home_banners`. ON_RESUME is
            // dispatched to a newly registered observer too, so this also covers
            // the cold launch — no separate LaunchedEffect needed. Fires on
            // foreground AND on return from a Flutter page, the latter being
            // when the unread count drops.
            badgeScope.launch { homeBanners.refresh() }
        }
        fun openTab(route: FlutterRoute, from: NavTab) {
            if (launching.value) return
            launching.value = true
            // Keep-host: open the Flutter page over the shell WITHOUT switching tabs, so
            // back returns to `from`. recreateArgs restores that tab if the OS reclaims the
            // host while backgrounded.
            nav.requestFlutterRouteKeepingHost(
                route = route.route,
                args = route.args,
                recreateKey = "bottom_nav_shell",
                recreateArgs = mapOf("initialTab" to from.name),
            )
        }
        TabNavigator(
            state = state,
            onExit = onExit, // start-tab back exits the app (root shell) — host-provided
            bottomBar = { current, onSelect ->
                // Tabs are indexed off the visible list, never NavTab.ordinal — Notifications
                // sits in the middle, so gating it off shifts every position after it.
                val notificationsEnabled = remoteConfig.getBool(RC_NOTIFICATIONS_TAB, default = false)
                val tabs = remember(isSuspended, notificationsEnabled) {
                    visibleNavTabs(isSuspended, notificationsEnabled)
                }
                val hasUnread = homeBannersState.hasUnreadNotifications
                // Keyed on the flag too, or the dot never repaints when it flips.
                val specs = remember(tabs, hasUnread) {
                    tabs.map { tabSpec(it, hasUnreadNotifications = hasUnread) }
                }
                Column {
                    // Feature #2: inline offline strip flush above the tab bar, over the
                    // last-known DB state. Scoped to true Offline (the engine's Offline
                    // gate + #2's intent); BadConnection is a coarse OS heuristic we don't
                    // warn on app-wide. (Review #5.)
                    if (connectivity == ConnectivityStatus.Offline) {
                        SnabbitConnectivityBanner(status = connectivity)
                    }
                    SnabbitBottomTabBar(
                        tabs = specs,
                        selectedIndex = tabs.indexOf(current).coerceAtLeast(0),
                        onSelect = { index ->
                            val tapped = tabs[index]
                            analytics.track(
                                "bottom_nav_cta_click",
                                mapOf("cta_text" to tapped.name.lowercase()),
                            )
                            when (tapped) {
                                // Earnings/Refer are "open a page" shortcuts: launch the Flutter
                                // page over the shell and stay on the current tab (back returns here).
                                NavTab.Earnings -> openTab(
                                    ProfileRouteDecider.monthlyEarnings(
                                        profileStore.snapshot()?.isRateCardV2Effective ?: false,
                                    ),
                                    current,
                                )
                                NavTab.Refer -> openTab(
                                    ProfileRouteDecider.referAndEarn(
                                        referralsV2Enabled = remoteConfig.getBool(
                                            ProfileRouteDecider.RC_REFERRALS_V2,
                                            default = false,
                                        ),
                                        entryPoint = "refer_tab",
                                    ),
                                    current,
                                )
                                NavTab.Notifications -> openTab(
                                    FlutterRoute(
                                        ProfileFlutterRoutes.APP_WEB_VIEW,
                                        mapOf(
                                            "webviewPath" to ProfileFlutterRoutes.WEBVIEW_NOTIFICATION_CENTRE,
                                            "title" to "Updates",
                                            "entryPoint" to "notifications_tab",
                                        ),
                                    ),
                                    current,
                                )
                                // Home / Profile → switch to that tab's native content.
                                else -> onSelect(tapped)
                            }
                        },
                    )
                }
            },
            // Active-job screen + Auto-OT sheet drawn over the tabs (state-driven; each self-hides).
            overlay = {
                ActiveJobOverlay()
                AutoOtOverlay()
            },
            content = { tab ->
                when (tab) {
                    // Home/Profile tab content self-resolve their VM via koinViewModel()
                    // (retained per nav-entry), so the shell registration stays VM-wiring-free.
                    NavTab.Home -> HomeTabContent()
                    // onSwitchToHome: post-emergency-logout handover so the
                    // PA sheet auto-mounting on Home is seen (ECPO-843).
                    NavTab.Profile -> ProfileTabContent(
                        onSwitchToHome = { state.switchTab(NavTab.Home) },
                    )
                    else -> ComingSoonScreen(
                        tabLabel = tab.name,
                        icon = comingSoonActiveIcon(tab.name),
                    )
                }
            },
        )
        // App-scoped SOS host — SOS is job-independent (contract §3) and must work from ANY screen.
        // The alert sheet + SosActive nav live here at the shell level, off the process-scoped
        // SosCoordinator, so every tab's SOS pill just calls raiseManual() and this renders the UI.
        AppSosHost()
    }
}
