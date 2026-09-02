package com.snabbit.runner.shared.features.bottomnav

import com.snabbit.runner.shared.resources.Res
import com.snabbit.runner.shared.resources.tab_earnings_active
import com.snabbit.runner.shared.resources.tab_notifications_inactive
import com.snabbit.runner.shared.resources.tab_profile_active
import com.snabbit.runner.shared.resources.tab_refer_active
import org.jetbrains.compose.resources.DrawableResource

/**
 * Maps a not-yet-built tab's label to the "active" tab icon shown alongside its
 * placeholder content. Pure and exhaustive so it's testable outside the Koin/Compose
 * wiring in `:app` — [NavTab.Profile] and any unrecognised label both fall through to the
 * profile icon.
 */
fun comingSoonActiveIcon(tabLabel: String): DrawableResource = when (tabLabel) {
    NavTab.Earnings.name -> Res.drawable.tab_earnings_active
    NavTab.Refer.name -> Res.drawable.tab_refer_active
    NavTab.Notifications.name -> Res.drawable.tab_notifications_inactive
    else -> Res.drawable.tab_profile_active
}
