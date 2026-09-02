package com.snabbit.runner.shared.features.gamification.domain.model

/**
 * Post-action reward / penalty / waiver outcome — the KMP port of Dart
 * `lib/models/gamification/post_action_outcome.dart`. Drives the post-action
 * popup + coin-flight animation, or (when [isWaived]) the waiver bottom sheet.
 *
 * [goldCoins] / [redCards] are the **deltas** for this action; [goldCoinsTotal]
 * / [redCardsTotal] are the **authoritative balances** after it (totals win over
 * deltas when both are present).
 */
data class PostActionOutcome(
    val lifecycleActionType: String = "",
    val status: OutcomeStatus,
    val label: NudgeLabel,
    val subtitleLabel: NudgeLabel? = null,
    val goldCoins: Int = 0,
    val redCards: Int = 0,
    val goldCoinsTotal: Int? = null,
    val redCardsTotal: Int? = null,
    /** Title-ribbon leading image; UI falls back to a solid dot when absent. */
    val iconUrl: String? = null,
) {
    val isReward: Boolean get() = goldCoins > 0
    val isPenalty: Boolean get() = redCards > 0
    val isWaived: Boolean get() = status == OutcomeStatus.Waived
}
