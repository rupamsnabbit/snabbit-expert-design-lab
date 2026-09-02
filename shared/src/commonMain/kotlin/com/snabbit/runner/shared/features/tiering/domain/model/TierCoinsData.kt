package com.snabbit.runner.shared.features.tiering.domain.model

import kotlinx.collections.immutable.ImmutableList
import kotlinx.collections.immutable.persistentListOf

/**
 * Weekly Snabbit-coins progress for the tier nudge (`THE_COIN_NUDGE`).
 *
 * Pure domain model — mirrors the Flutter `TierCoinsData` (rich weeks/targets
 * shape). No serialization here: the components render it, and the eventual
 * data layer maps its DTO into this.
 */
data class TierCoinsData(
    val coinBalance: Int? = null,
    val coins: TierCoinsProgress? = null,
)

/** The `coins` object — the weekly rollup plus which week is active. */
data class TierCoinsProgress(
    val currentWeek: Int? = null,
    val weeks: ImmutableList<TierWeek> = persistentListOf(),
) {
    /** The week whose [TierWeek.week] matches [currentWeek] (drives the card), or null. */
    val activeWeek: TierWeek?
        get() = currentWeek?.let { week -> weeks.firstOrNull { it.week == week } }
}

/** One week's earnings and, for the in-progress week, its milestone [targets]. */
data class TierWeek(
    val week: Int? = null,
    val earned: Int? = null,
    val state: TierWeekState? = null,
    val targets: ImmutableList<TierTarget> = persistentListOf(),
) {
    /** Largest milestone amount — the full scale of the progress bar (0 when none). */
    val maxTargetAmount: Int
        get() = targets.maxOfOrNull { it.amount ?: 0 } ?: 0

    /** [earned] / [maxTargetAmount], clamped to 0..1 (0 when there is no positive target). */
    val progressFraction: Float
        get() {
            val max = maxTargetAmount
            if (max <= 0) return 0f
            return ((earned ?: 0).toFloat() / max).coerceIn(0f, 1f)
        }
}

/** A milestone on the progress bar: earn [amount] coins to reach [tier]. */
data class TierTarget(
    val amount: Int? = null,
    val tier: Tier? = null,
)

/** Lifecycle of a [TierWeek] (`state`). */
enum class TierWeekState {
    COMPLETED,
    IN_PROGRESS,
    ;

    companion object {
        /** Parse the wire `state` string (case-insensitive); unknown/blank → null. */
        fun fromWire(value: String?): TierWeekState? = when (value?.trim()?.lowercase()) {
            "completed" -> COMPLETED
            "in_progress" -> IN_PROGRESS
            else -> null
        }
    }
}

/**
 * Runner tiers. [displayName] backs the header label ("Pink Diamond Tier").
 *
 * Two schemes coexist: the **legacy** (sunset) tiers [BASIC] / [PRO] / [ELITE]
 * ([isLegacyTier]) and the **new** scheme [BASE] / [SILVER] / [GOLD] / [DIAMOND] /
 * [PINK_DIAMOND]. `BASIC` is a **distinct** legacy tier — NOT an alias of the new
 * `BASE` — so a just-promoted runner (new `tier`, effective date still in the
 * future) is classified by tier identity. Mirrors Flutter's `Tier` enum.
 */
enum class Tier(val displayName: String) {
    BASIC("Basic"),
    BASE("Base"),
    PRO("Pro"),
    ELITE("Elite"),
    SILVER("Silver"),
    GOLD("Gold"),
    DIAMOND("Diamond"),
    PINK_DIAMOND("Pink Diamond"),
    ;

    /**
     * The sunset tiers (`BASIC` / `PRO` / `ELITE`) — the old scheme. The tiering
     * surfaces gate on this (tier identity), not the effective date, so a runner
     * promoted into the new scheme sees consistent chrome immediately. Mirrors
     * Flutter `Tier.isLegacyTier`.
     */
    val isLegacyTier: Boolean get() = this == BASIC || this == PRO || this == ELITE

    companion object {
        /** Parse a wire tier string (case-insensitive); unknown/blank → null (mirrors Flutter `Tier.fromString`). */
        fun fromWire(value: String?): Tier? = when (value?.trim()?.uppercase()) {
            // BASIC is a DISTINCT legacy tier — NOT an alias of the new BASE.
            "BASIC" -> BASIC
            "BASE" -> BASE
            "PRO" -> PRO
            "ELITE" -> ELITE
            "SILVER" -> SILVER
            "GOLD" -> GOLD
            "DIAMOND" -> DIAMOND
            "PINK_DIAMOND" -> PINK_DIAMOND
            else -> null
        }
    }
}
