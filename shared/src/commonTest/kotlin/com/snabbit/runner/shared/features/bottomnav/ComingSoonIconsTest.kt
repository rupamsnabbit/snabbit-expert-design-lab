package com.snabbit.runner.shared.features.bottomnav

import com.snabbit.runner.shared.resources.Res
import com.snabbit.runner.shared.resources.tab_earnings_active
import com.snabbit.runner.shared.resources.tab_notifications_inactive
import com.snabbit.runner.shared.resources.tab_profile_active
import com.snabbit.runner.shared.resources.tab_refer_active
import kotlin.test.Test
import kotlin.test.assertEquals

class ComingSoonIconsTest {
    @Test fun maps_each_tab_label_to_its_active_icon() {
        assertEquals(Res.drawable.tab_earnings_active, comingSoonActiveIcon("Earnings"))
        assertEquals(Res.drawable.tab_refer_active, comingSoonActiveIcon("Refer"))
        assertEquals(Res.drawable.tab_notifications_inactive, comingSoonActiveIcon("Notifications"))
        assertEquals(Res.drawable.tab_profile_active, comingSoonActiveIcon("Profile"))
        assertEquals(Res.drawable.tab_profile_active, comingSoonActiveIcon("anything-unknown")) // else branch
    }
}
