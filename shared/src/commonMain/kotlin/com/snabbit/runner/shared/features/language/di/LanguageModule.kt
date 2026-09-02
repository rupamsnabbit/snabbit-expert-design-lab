package com.snabbit.runner.shared.features.language.di

import com.snabbit.runner.shared.core.navigation.di.nativeDestination
import com.snabbit.runner.shared.features.language.LanguageDestination
import com.snabbit.runner.shared.features.language.data.LanguageDataSourceImpl
import com.snabbit.runner.shared.features.language.domain.LanguageDataSource
import com.snabbit.runner.shared.features.language.domain.usecase.SetLanguageUseCase
import org.koin.dsl.module

/**
 * Koin wiring for the Language feature (commonMain): the production
 * [LanguageDataSource] (network-backed via the core `SnabbitHttpClient`), the
 * [SetLanguageUseCase], and the native nav destination. Registered in
 * `KmpBootstrap.initialize`.
 *
 * The `LanguageViewModel` is intentionally NOT registered here — it is
 * constructed per nav-entry in the `:app` `nativeScreen<LanguageDestination>`
 * registration (scoped to the NavEntry's ViewModelStore), matching the Kavach
 * screens and the KMP navigation guide.
 *
 * `ProfileGateway` and `LanguageAnalytics` are Android bridge-backed, so `:app`'s
 * `languageScreenAppModule` registers them. They are never resolved on iOS (the
 * screen is Android-only), so the split keeps `commonMain` compiling for iOS.
 */
val languageModule = module {
    single<LanguageDataSource> {
        LanguageDataSourceImpl(httpClient = get(), crashReporter = get())
    }

    factory { SetLanguageUseCase(dataSource = get(), profileGateway = get()) }

    // Native nav destination — the Flutter drawer opens it via
    // `KmpNavigationBridge.openNativeDestination("language", …)`, and the Profile
    // tab via `nav.navigate(LanguageDestination(...))`. Rendered by
    // `nativeScreen<LanguageDestination>` in :app.
    nativeDestination<LanguageDestination>(key = "language") { args ->
        LanguageDestination(
            currentLanguage = args["currentLanguage"],
            title = args["title"],
            confirmLabel = args["confirmLabel"],
        )
    }
}
