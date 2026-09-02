package com.snabbit.runner.shared.features.home.di

import com.snabbit.runner.shared.core.localization.LocalizationStore
import com.snabbit.runner.shared.core.navigation.NavigationController
import com.snabbit.runner.shared.features.autoot.data.AutoOtCoordinator
import com.snabbit.runner.shared.features.home.presentation.HomeViewModel
import com.snabbit.runner.shared.features.shift.core.data.ShiftProjector
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.SupervisorJob
import org.koin.core.module.dsl.viewModel
import org.koin.dsl.module

val homeModule = module {
    // ponytail: read-model owns its supervisor scope so collection survives VM recreation.
    single { ShiftProjector(store = get(), scope = CoroutineScope(SupervisorJob()), logger = get()) }
    // Explicit constructor call (not viewModelOf): the reflection-free `*Of`
    // builder tries to resolve the DEFAULTED `strings`/`initialPhase` params
    // from the graph and crashes (no HomeStrings binding). Passing only the
    // required deps here lets Kotlin apply those defaults. Retrieved via
    // koinViewModel().
    viewModel {
        val nav = get<NavigationController>()
        val localization = get<LocalizationStore>()
        HomeViewModel(
            readModel = get(),
            gamification = get(),
            attendanceRepository = get(),
            shiftRepository = get(),
            postActionCoordinator = get(),
            lunchReadModel = get(),
            lunchRepository = get(),
            sevaRepository = get(),
            suspendedReadModel = get(),
            suspendedRepository = get(),
            seeYouTomorrowReadModel = get(),
            homeBannersStore = get(),
            locationProvider = get(),
            analytics = get(),
            currentTimeMs = get(),
            // Saathi pill → IVR-first masked call with a dialer fallback (Flutter
            // `CallUtils.handleCallInitiation`). Reuses the job-feature masked-call source
            // (`single<CallingDataSource>` in JobModule) + dialer seam, and the shared
            // RemoteConfig gateway for the helpline number (default baked in).
            callingDataSource = get(),
            customerContactLauncher = get(),
            remoteConfig = get(),
            // Coins pill → gold-coins rewards webview, keeping Home alive (Dart
            // `AppWebViewPage` + `WebviewRoutes.payoutsRewardsGoldCoins`). The page
            // resolves `webviewPath` via Dart `buildWebviewUrl`; recreateKey/args
            // rebuild the Home shell if the OS reclaims it. Mirrors ProfileModule.
            openCoinsPage = {
                nav.requestFlutterRouteKeepingHost(
                    route = "/app-web-view",
                    args = mapOf(
                        "webviewPath" to "v1/payouts/rewards?type=gold_coins",
                        "title" to "Gold coins",
                    ),
                    recreateKey = "bottom_nav_shell",
                    recreateArgs = mapOf("initialTab" to "Home"),
                )
            },
            // Red card pill → red-cards rewards webview (Dart
            // `WebviewRoutes.payoutsRewardsRedCards`) — exact mirror of the
            // coins hop above, different query + title.
            openRedCardsPage = {
                nav.requestFlutterRouteKeepingHost(
                    route = "/app-web-view",
                    args = mapOf(
                        "webviewPath" to "v1/payouts/rewards?type=red_cards",
                        "title" to "Red cards",
                    ),
                    recreateKey = "bottom_nav_shell",
                    recreateArgs = mapOf("initialTab" to "Home"),
                )
            },
            openSaathiSupportPage = {
                nav.requestFlutterRouteKeepingHost(
                    route = "/app-web-view",
                    args = mapOf(
                        "webviewPath" to "v1/support",
                        "title" to localization.getMessage("common.saathi", "Saathi"),
                    ),
                    recreateKey = "bottom_nav_shell",
                    recreateArgs = mapOf("initialTab" to "Home"),
                )
            },
            // App-scoped SOS coordinator — the home top-nav SOS pill raises a job-independent SOS.
            sosCoordinator = get(),
            sosVisibility = get(),
            // Auto-OT coordinator — the START_OT probe fires after an attendance mark.
            autoOtCoordinator = get<AutoOtCoordinator>(),
            // Banner taps navigate through the shared controller (CMP push or
            // keep-host Flutter hop — resolved per clickPath in the VM).
            nav = nav,
            // runners/me read model — the `decider:earnings` banner gate + the
            // profile photo for the map's "you are here" marker.
            profileStore = get(),
            // Runner-consent gate — drives the home consent sheet (Flutter parity).
            kavachConsent = get(),
            // GPS-service gate (ECPO-873, reduced scope) — Dart owns permission/background/precise.
            permissionObserver = get(),
        )
    }
}
