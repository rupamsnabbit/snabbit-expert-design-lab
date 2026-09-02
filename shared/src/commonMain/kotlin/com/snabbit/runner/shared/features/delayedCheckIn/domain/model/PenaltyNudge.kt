package com.snabbit.runner.shared.features.job.delayedcheckin.domain.model

/**
 * Optional nudge strip shown under the countdown (e.g. "2nd red card in the
 * last 7 days"). Decoded from the `nudge` object on the
 * `delayed_checkin_penalty` payload by
 * [com.snabbit.runner.shared.features.job.delayedcheckin.data.decodeAwaitingCheckin] —
 * a malformed or absent `nudge` resolves to `null` there, never to this type
 * with blank fields.
 */
data class PenaltyNudge(
    val label: String,
    val redCards: Int? = null,
    val iconUrl: String? = null,
)
