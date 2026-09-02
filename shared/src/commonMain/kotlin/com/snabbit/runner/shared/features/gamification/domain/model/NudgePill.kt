package com.snabbit.runner.shared.features.gamification.domain.model

/**
 * Trailing coin / red-card pill for a nudge strip — the KMP port of Dart
 * `lib/models/gamification/nudge_pill.dart`. Derived purely from the coin /
 * red-card counts; there is no `badgeText` in the API.
 */
enum class NudgePillKind { None, Coin, RedCard }

data class NudgePill(
    val kind: NudgePillKind,
    val count: Int,
) {
    val hasPill: Boolean get() = kind != NudgePillKind.None && count > 0

    companion object {
        val None = NudgePill(NudgePillKind.None, 0)
    }
}

/** If [goldCoins] > 0 → coin pill; else if [redCards] > 0 → red-card pill; else none. */
fun deriveNudgePill(goldCoins: Int?, redCards: Int?): NudgePill = when {
    (goldCoins ?: 0) > 0 -> NudgePill(NudgePillKind.Coin, goldCoins!!)
    (redCards ?: 0) > 0 -> NudgePill(NudgePillKind.RedCard, redCards!!)
    else -> NudgePill.None
}
