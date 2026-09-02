package com.snabbit.runner.shared.features.bottomnav

import com.snabbit.runner.shared.core.navigation.Destination
import kotlinx.serialization.Serializable

/** The five tabs of the runner bottom navigation. */
enum class NavTab { Home, Earnings, Refer, Notifications, Profile }

/**
 * Root native destination for the bottom-nav shell — hosts the tab scaffold. Opened by
 * Flutter via the nav bridge: `openNativeDestination('bottom_nav_shell', {})`. The wire
 * key is a Dart/native contract — rename both sides in lockstep. [initialTab] selects
 * which [NavTab] is shown first; defaults to [NavTab.Home].
 */
@Serializable
data class BottomNavHost(val initialTab: String = NavTab.Home.name) : Destination
