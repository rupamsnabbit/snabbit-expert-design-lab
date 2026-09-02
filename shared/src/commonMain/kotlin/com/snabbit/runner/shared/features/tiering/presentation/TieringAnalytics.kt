package com.snabbit.runner.shared.features.tiering.presentation

import com.snabbit.runner.shared.core.analytics.AnalyticsTracker
import com.snabbit.runner.shared.core.analytics.ProviderKeys
import com.snabbit.runner.shared.features.tiering.domain.model.Tier
import com.snabbit.runner.shared.features.tiering.domain.model.TierNudge

/**
 * Tiering analytics — the KMP port of the Flutter `TieringAnalytics`. Every event
 * fans to BOTH Mixpanel and CleverTap via explicit [targets] (the tiering event
 * names aren't in the KMP route catalog, so — like the webview sink — both
 * providers are named here). Event names + prop keys match Dart 1:1.
 */
class TieringAnalytics(private val tracker: AnalyticsTracker) {

    fun nudgeViewed(nudge: TierNudge, tier: Tier?, renderType: String) =
        track(EVENT_NUDGE_VIEWED, nudgeProps(nudge, tier, renderType))

    fun nudgeClicked(nudge: TierNudge, tier: Tier?, renderType: String) =
        track(EVENT_NUDGE_CLICKED, nudgeProps(nudge, tier, renderType))

    fun bannerViewed(showHeaderImage: Boolean) =
        track(EVENT_BANNER_VIEWED, mapOf(PROP_SHOW_HEADER to showHeaderImage))

    fun bannerClicked(showHeaderImage: Boolean) =
        track(EVENT_BANNER_CLICKED, mapOf(PROP_SHOW_HEADER to showHeaderImage))

    // The surface is the profile tier card (not a drawer); the wire event names keep the
    // legacy `..._view_tier_drawer_...` strings for Dart/dashboard parity — see the consts below.
    fun profileTierViewed(tier: Tier?) = track(EVENT_DRAWER_VIEWED, mapOf(PROP_TIER to tierName(tier)))

    fun profileTierClicked(tier: Tier?) = track(EVENT_DRAWER_CLICKED, mapOf(PROP_TIER to tierName(tier)))

    private fun nudgeProps(nudge: TierNudge, tier: Tier?, renderType: String): Map<String, Any?> = mapOf(
        PROP_NUDGE_NAME to nudge.nudgeName.orEmpty(),
        PROP_THEME to nudge.theme.name,
        PROP_TIER to tierName(tier),
        PROP_RENDER_TYPE to renderType,
        PROP_NAV_ROUTE to nudge.navigationRoute.orEmpty(),
    )

    private fun tierName(tier: Tier?): String = tier?.name.orEmpty()

    private fun track(name: String, props: Map<String, Any?>) =
        tracker.track(name, props, targets = BOTH_PROVIDERS)

    companion object {
        const val RENDER_TYPE_COINS_CARD = "coins_card"
        const val RENDER_TYPE_JOB = "job"
        const val RENDER_TYPE_THEMED = "themed"

        private val BOTH_PROVIDERS = setOf(ProviderKeys.MIXPANEL, ProviderKeys.CLEVERTAP)

        private const val EVENT_NUDGE_VIEWED = "tiering_nudge_viewed"
        private const val EVENT_NUDGE_CLICKED = "tiering_nudge_clicked"
        private const val EVENT_BANNER_VIEWED = "tiering_udaan_banner_viewed"
        private const val EVENT_BANNER_CLICKED = "tiering_udaan_banner_clicked"
        private const val EVENT_DRAWER_VIEWED = "tiering_view_tier_drawer_viewed"
        private const val EVENT_DRAWER_CLICKED = "tiering_view_tier_drawer_clicked"

        private const val PROP_NUDGE_NAME = "nudge_name"
        private const val PROP_THEME = "theme"
        private const val PROP_TIER = "tier"
        private const val PROP_RENDER_TYPE = "render_type"
        private const val PROP_NAV_ROUTE = "navigation_route"
        private const val PROP_SHOW_HEADER = "show_header_image"
    }
}
