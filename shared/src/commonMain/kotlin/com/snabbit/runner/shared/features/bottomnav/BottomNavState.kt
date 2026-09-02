package com.snabbit.runner.shared.features.bottomnav

/**
 * Resolves the bottom nav's start tab from the [BottomNavHost.initialTab] string (matched
 * by [NavTab.name]), falling back to [NavTab.Home] for an empty or unrecognised value.
 * Pure and testable outside the Koin/Compose wiring in `:app`.
 */
internal fun startNavTab(initialTab: String): NavTab =
    NavTab.entries.firstOrNull { it.name == initialTab } ?: NavTab.Home

internal fun visibleNavTabs(isSuspended: Boolean, notificationsEnabled: Boolean): List<NavTab> =
    NavTab.entries.filter { tab ->
        when (tab) {
            NavTab.Profile -> !isSuspended
            NavTab.Notifications -> notificationsEnabled
            else -> true
        }
    }
