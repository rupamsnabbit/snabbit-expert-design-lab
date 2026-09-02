package com.snabbit.runner.shared.core.navigation.tabs

import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

/**
 * Selected-tab holder for a [TabNavigator]. Tabs are **single-screen** — there is no
 * per-tab back stack, so switching just changes [currentTab]. (Deeper navigation pushes a
 * destination onto the main `NavigationController`, which covers the whole shell; if a tab
 * ever needs its *own* internal stack, reintroduce one here.)
 *
 * Back ([handleBack]): a non-start tab returns to [startTab] (exit-through-home) and
 * reports consumed; at the start tab it returns `false` so the caller exits the container.
 */
@Stable
class TabNavigatorState<Tab>(
    val tabs: List<Tab>,
    val startTab: Tab,
) {
    var currentTab: Tab by mutableStateOf(startTab)
        private set

    fun switchTab(tab: Tab) {
        if (tab in tabs) currentTab = tab
    }

    /** Switch to [startTab] if elsewhere (returns `true`); at [startTab] returns `false`. */
    fun handleBack(): Boolean {
        if (currentTab != startTab) {
            currentTab = startTab
            return true
        }
        return false
    }
}
