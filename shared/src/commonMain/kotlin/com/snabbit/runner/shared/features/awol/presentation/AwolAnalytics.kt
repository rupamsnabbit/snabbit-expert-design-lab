package com.snabbit.runner.shared.features.awol.presentation

import com.snabbit.runner.shared.core.analytics.AnalyticsTracker

/**
 * Analytics for AWOL (out-of-hotspot) penalties — expert-v2 dictionary (PRD M2.10).
 * Routed to Mixpanel + CleverTap via `AnalyticsRoutesConfig`.
 *
 * Fired from the background coordinator ([AwolViewModel]), not a UI intent —
 * the penalty is minted server-side and detected here on meter expiry.
 *
 * ponytail: the spec's per-penalty `red_cards_received` delta is server-owned and
 * not exposed on the envelope; we send the running `red_cards_total` instead. If a
 * true delta is needed, the backend must add it to the `widget_data.awol` payload.
 */
class AwolAnalytics(private val tracker: AnalyticsTracker) {

    /** A red card was applied for time-out-of-hotspot (meter expired). */
    fun penaltyApplied(redCardsTotal: Int, penaltyStage: Int?, minutesOutOfHotspot: Int?) =
        tracker.track(
            EVENT_PENALTY_APPLIED,
            mapOf(
                // Spec key is `red_cards_received`; the server-owned per-penalty delta
                // isn't on the envelope, so we send the running total under the spec key
                // (a dashboard keyed on `red_cards_received` reads this, not zero).
                PROP_RED_CARDS_RECEIVED to redCardsTotal,
                PROP_PENALTY_STAGE to penaltyStage,
                PROP_MINUTES_OUT to minutesOutOfHotspot,
            ),
        )

    private companion object {
        const val EVENT_PENALTY_APPLIED = "awol_penalty_applied"
        const val PROP_RED_CARDS_RECEIVED = "red_cards_received"
        const val PROP_PENALTY_STAGE = "penalty_stage"
        const val PROP_MINUTES_OUT = "minutes_out_of_hotspot"
    }
}
