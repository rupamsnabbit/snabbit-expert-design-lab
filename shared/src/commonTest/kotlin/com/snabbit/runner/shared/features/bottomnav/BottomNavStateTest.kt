package com.snabbit.runner.shared.features.bottomnav

import kotlin.test.Test
import kotlin.test.assertEquals

class BottomNavStateTest {
    @Test fun start_tab_defaults_to_home() {
        assertEquals(NavTab.Home, startNavTab(NavTab.Home.name))
    }

    @Test fun start_tab_honours_a_non_home_initial_tab() {
        assertEquals(NavTab.Earnings, startNavTab(NavTab.Earnings.name))
    }

    @Test fun start_tab_falls_back_to_home_for_unknown_tab() {
        assertEquals(NavTab.Home, startNavTab("bogus"))
    }

    @Test fun all_tabs_show_when_enabled_and_not_suspended() {
        assertEquals(
            listOf(NavTab.Home, NavTab.Earnings, NavTab.Refer, NavTab.Notifications, NavTab.Profile),
            visibleNavTabs(isSuspended = false, notificationsEnabled = true),
        )
    }

    @Test fun notifications_hidden_when_flag_is_off() {
        assertEquals(
            listOf(NavTab.Home, NavTab.Earnings, NavTab.Refer, NavTab.Profile),
            visibleNavTabs(isSuspended = false, notificationsEnabled = false),
        )
    }

    @Test fun profile_hidden_while_suspended() {
        assertEquals(
            listOf(NavTab.Home, NavTab.Earnings, NavTab.Refer, NavTab.Notifications),
            visibleNavTabs(isSuspended = true, notificationsEnabled = true),
        )
    }

    @Test fun both_hidden_when_suspended_and_flag_off() {
        assertEquals(
            listOf(NavTab.Home, NavTab.Earnings, NavTab.Refer),
            visibleNavTabs(isSuspended = true, notificationsEnabled = false),
        )
    }

    @Test fun tap_index_resolves_off_the_visible_list_not_the_ordinal() {
        val tabs = visibleNavTabs(isSuspended = false, notificationsEnabled = false)

        assertEquals(NavTab.Profile, tabs[3])
        assertEquals(NavTab.Notifications, NavTab.entries[3])
    }

    @Test fun every_visible_tab_round_trips_through_its_index() {
        for (suspended in listOf(false, true)) {
            for (enabled in listOf(false, true)) {
                val tabs = visibleNavTabs(suspended, enabled)
                tabs.forEach { tab -> assertEquals(tab, tabs[tabs.indexOf(tab)]) }
            }
        }
    }
}
