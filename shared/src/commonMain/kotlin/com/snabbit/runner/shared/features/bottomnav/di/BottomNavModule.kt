package com.snabbit.runner.shared.features.bottomnav.di

import com.snabbit.runner.shared.core.navigation.di.nativeDestination
import com.snabbit.runner.shared.features.bottomnav.BottomNavHost
import com.snabbit.runner.shared.features.bottomnav.NavTab
import org.koin.dsl.module

val bottomNavModule = module {
    // Opened by Flutter via the nav bridge: openNativeDestination('bottom_nav_shell', {}).
    // The key is a Dart/native contract — rename both sides in lockstep (see BottomNavHost).
    nativeDestination<BottomNavHost>(key = "bottom_nav_shell") { args ->
        BottomNavHost(initialTab = args["initialTab"] ?: NavTab.Home.name)
    }
}
