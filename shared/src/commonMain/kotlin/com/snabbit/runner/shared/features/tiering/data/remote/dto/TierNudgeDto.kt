package com.snabbit.runner.shared.features.tiering.data.remote.dto

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonObject

/**
 * Wire shape of `current_state.tier_nudge`. `nudgeDetails` stays raw — the coins
 * body ([TierCoinsDto]) is decoded on demand only for `THE_COIN_NUDGE`, so a new
 * per-nudge field never forces a schema change here.
 */
@Serializable
internal data class TierNudgeDto(
    @SerialName("nudge_name") val nudgeName: String? = null,
    @SerialName("navigation_route") val navigationRoute: String? = null,
    @SerialName("image_url") val imageUrl: String? = null,
    @SerialName("theme") val theme: String? = null,
    @SerialName("nudge_details") val nudgeDetails: JsonObject? = null,
)

/** `THE_COIN_NUDGE` `nudge_details` — the coin balance + weekly rollup. */
@Serializable
internal data class TierCoinsDto(
    @SerialName("coin_balance") val coinBalance: Int? = null,
    @SerialName("coins") val coins: TierCoinsProgressDto? = null,
)

@Serializable
internal data class TierCoinsProgressDto(
    @SerialName("current_week") val currentWeek: Int? = null,
    @SerialName("weeks") val weeks: List<TierWeekDto> = emptyList(),
)

@Serializable
internal data class TierWeekDto(
    @SerialName("week") val week: Int? = null,
    @SerialName("earned") val earned: Int? = null,
    @SerialName("state") val state: String? = null,
    @SerialName("targets") val targets: List<TierTargetDto> = emptyList(),
)

@Serializable
internal data class TierTargetDto(
    @SerialName("amount") val amount: Int? = null,
    @SerialName("tier") val tier: String? = null,
)
