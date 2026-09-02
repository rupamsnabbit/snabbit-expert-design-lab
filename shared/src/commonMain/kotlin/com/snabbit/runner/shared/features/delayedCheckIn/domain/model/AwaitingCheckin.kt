package com.snabbit.runner.shared.features.job.delayedcheckin.domain.model

import kotlin.time.Instant

/**
 * Decoded `widget_data.delayed_checkin_penalty` payload — the expert has a
 * job awaiting check-in and is being penalised (red cards) if they don't
 * reach the doorstep by [deadline].
 *
 * Built by [com.snabbit.runner.shared.features.job.delayedcheckin.data.decodeAwaitingCheckin];
 * see that function for the defaulting table applied to each field.
 */
data class AwaitingCheckin(
    val deadline: Instant,
    val totalSeconds: Int = 300,
    val receivedRedCards: Int = 0,
    val cardValue: Int? = null,
    val nudge: PenaltyNudge? = null,
) {
    /**
     * Analytics dedupe key — one `delayed_checkin_penalty_popup_viewed`
     * event per deadline, not per recomposition/re-push of the same
     * countdown. See
     * [com.snabbit.runner.shared.features.job.delayedcheckin.DelayedCheckinAnalytics.popupViewed].
     */
    val dedupeKey: Long get() = deadline.toEpochMilliseconds()
}
