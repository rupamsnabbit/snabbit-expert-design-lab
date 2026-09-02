package com.snabbit.runner.language

import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.snabbit.runner.shared.core.navigation.di.nativeScreen
import com.snabbit.runner.shared.features.language.LanguageAnalytics
import com.snabbit.runner.shared.features.language.LanguageDestination
import com.snabbit.runner.shared.features.language.domain.ProfileGateway
import com.snabbit.runner.shared.features.language.presentation.LanguageScreen
import com.snabbit.runner.shared.features.language.presentation.LanguageStrings
import com.snabbit.runner.shared.features.language.presentation.localized
import com.snabbit.runner.shared.features.language.presentation.LanguageUiIntent
import com.snabbit.runner.shared.features.language.presentation.LanguageViewModel
import org.koin.dsl.module
import org.koin.mp.KoinPlatform.getKoin

/**
 * `:app` Koin module for the Language screen. Registers:
 *  - the Android bridge seams [ProfileGateway] + [LanguageAnalytics] as app
 *    singletons (Flutter MethodChannel-backed) — resolved by the VM at runtime;
 *  - the native nav destination ([LanguageDestination]) — opened from the Flutter
 *    drawer via the KMP nav bridge (`openNativeDestination("language", …)`) or the
 *    Profile tab via `NavigationController`, rendered inside the single nav host
 *    (back returns to the caller).
 *
 * Loaded via `loadKoinModules` in `SnabbitRunnerApplication` after `KmpBootstrap`,
 * so `getAll<NativeScreen>()` picks up the registration.
 */
val languageScreenAppModule = module {
    single<ProfileGateway> {
        ProfileGatewayImpl(crashReporter = get(), runnerProfileStore = get())
    }
    single<LanguageAnalytics> { LanguageAnalyticsImpl() }

    nativeScreen<LanguageDestination> { dest ->
        val strings = remember(dest) {
            LanguageStrings(
                title = dest.title ?: LanguageStrings().title,
                confirmButton = dest.confirmLabel ?: LanguageStrings().confirmButton,
            ).localized(getKoin().get())
        }
        // viewModel { } scopes the VM to THIS NavEntry (host ViewModelStore
        // decorator) — survives config change, cleared when the entry is popped.
        val vm = viewModel {
            LanguageViewModel(
                dataSource = getKoin().get(),
                setLanguage = getKoin().get(),
                analytics = getKoin().get(),
                nav = getKoin().get(),
                strings = strings,
                currentLanguage = dest.currentLanguage,
            )
        }
        val state by vm.uiState.collectAsStateWithLifecycle()
        LanguageScreen(
            state = state,
            strings = strings,
            onIntent = vm::onIntent,
            onNavigateUp = { vm.onIntent(LanguageUiIntent.NavigateUp) },
        )
    }
}
