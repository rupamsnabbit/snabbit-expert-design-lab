package com.snabbit.runner.shared.core.navigation.di

import com.snabbit.runner.shared.core.navigation.DeeplinkMapping
import com.snabbit.runner.shared.core.navigation.DeeplinkResolver
import com.snabbit.runner.shared.core.navigation.DestinationFactory
import com.snabbit.runner.shared.core.navigation.NavigationController
import com.snabbit.runner.shared.core.navigation.ShellLoanRequest
import org.koin.dsl.module

/**
 * Koin wiring for the navigation module. Platform-free — the back stack and
 * routing logic are pure Kotlin. Registered in `KmpBootstrap.initialize`.
 *
 * [DeeplinkResolver] and [NavigationController]'s [DestinationFactory]s are
 * collected from every feature module via `getAll`, so a feature adds a deep-linked
 * or openable native screen by binding its own mapping/factory — no edit here. With
 * no native screens yet, `getAll` returns empty lists, which is correct.
 *
 * The Android Nav3 host + per-screen Composables are host-side concerns and live
 * in `:app`; they consume [NavigationController] from here.
 */
val navigationModule = module {
    single { DeeplinkResolver(mappings = getAll<DeeplinkMapping>()) }
    single {
        NavigationController(
            deeplinkResolver = get(),
            destinationFactories = getAll<DestinationFactory>(),
            logger = get(),
            crashReporter = get(),
        )
    }
    // Deep-link → running-shell channel for the native Profile-tab loan sheet
    // (see ShellLoanRequest). Process-scoped: the bridge writes it, the shell + Profile
    // tab read it. Core (not a feature) to avoid a bottomnav↔profile dependency cycle.
    single { ShellLoanRequest() }
}
