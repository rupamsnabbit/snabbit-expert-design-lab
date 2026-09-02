package com.snabbit.runner.shared.features.profile.di

import com.snabbit.runner.shared.core.analytics.AnalyticsTracker
import com.snabbit.runner.shared.core.navigation.NavigationController
import com.snabbit.runner.shared.features.profile.ExternalUrlOpener
import com.snabbit.runner.shared.features.profile.ProfileHostActions
import com.snabbit.runner.shared.features.profile.ProfileStrings
import com.snabbit.runner.shared.features.profile.localized
import com.snabbit.runner.shared.features.profile.ProfileViewModel
import com.snabbit.runner.shared.features.profile.RunnerProfileStore
import com.snabbit.runner.shared.features.profile.data.remote.ProfileRemoteDataSource
import com.snabbit.runner.shared.features.profile.data.remote.ProfileRemoteDataSourceImpl
import com.snabbit.runner.shared.features.profile.data.repository.ProfileRepositoryImpl
import com.snabbit.runner.shared.features.profile.domain.repository.ProfileRepository
import com.snabbit.runner.shared.features.profile.domain.usecase.GetProfileUseCase
import com.snabbit.runner.shared.features.language.LanguageDestination
import org.koin.core.module.dsl.viewModel
import org.koin.dsl.module

/**
 * Koin wiring for the Profile feature. Runner data is **bridge-fed**: Dart pushes `runners/me`
 * into [RunnerProfileStore] (KMP does not fetch it natively while the app is still mostly
 * Flutter — that would double the API), fed by the `:app` `ProfileSyncPlugin`. The
 * [ProfileHostActions] host bridge carries the Flutter-channel actions + debug flag, and the
 * [ProfileViewModel] (retained per nav-entry via `viewModel { }`, resolved by
 * `ProfileTabContent` through `koinViewModel()`) observes the store.
 *
 * The native `runners/me` data source + [GetProfileUseCase] stay registered but dormant on
 * Android — kept for a future iOS path that would fetch natively into the store. External-URL
 * opening comes via [ExternalUrlOpener] (androidMain, `profileAndroidModule`). Registered in
 * `KmpBootstrap.initialize`.
 */
val profileModule = module {
    single<ProfileRemoteDataSource> { ProfileRemoteDataSourceImpl(httpClient = get()) }
    single<ProfileRepository> { ProfileRepositoryImpl(remote = get()) }
    factory { GetProfileUseCase(repository = get()) }
    single { ProfileHostActions() }
    // Bridge-fed read model for runners/me: Dart pushes, KMP reads (no native fetch —
    // avoids doubling the API while Flutter still runs). Fed by the `:app` ProfileSyncPlugin.
    single { RunnerProfileStore(logger = get()) }

    viewModel {
        val nav = get<NavigationController>()
        val analytics = get<AnalyticsTracker>()
        val urlOpener = get<ExternalUrlOpener>()
        val host = get<ProfileHostActions>()
        ProfileViewModel(
            profileStore = get(),
            strings = ProfileStrings().localized(get()),
            openFlutterRoute = { route, args ->
                nav.requestFlutterRouteKeepingHost(
                    route = route,
                    args = args,
                    recreateKey = "bottom_nav_shell",
                    // "Profile" == NavTab.Profile.name — hardcoded to avoid a
                    // features/profile -> features/bottomnav dependency cycle.
                    recreateArgs = mapOf("initialTab" to "Profile"),
                )
            },
            openLanguage = { lang -> nav.navigate(LanguageDestination(currentLanguage = lang)) },
            trackEvent = { name, props -> analytics.track(name, props) },
            remoteConfig = get(),
            periodLeaveStore = get(),
            getLoanDetails = get(),
            openExternalUrl = { url -> urlOpener.open(url) },
            updatePan = get(),
            onSilentNotifications = { host.silentNotifications() },
            onPanCardUnavailable = { host.panCardUnavailable() },
            runnerStateStore = get(),
            isDebug = host.isDebug,
        )
    }
}
