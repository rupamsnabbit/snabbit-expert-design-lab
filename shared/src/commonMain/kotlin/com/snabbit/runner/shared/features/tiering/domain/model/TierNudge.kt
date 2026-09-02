package com.snabbit.runner.shared.features.tiering.domain.model

import kotlinx.serialization.json.JsonObject

/**
 * The `tier_nudge` object from `current_state` — a **top-level sibling** of
 * `widget_data` (not nested). Mirrors the Flutter `TierNudge`.
 *
 * [nudgeName] selects both the render variant and the hard-coded copy
 * ([com.snabbit.runner.shared.features.tiering.presentation.tierNudgeCopy]).
 * [nudgeDetails] is the raw per-nudge payload (the coins body for
 * `THE_COIN_NUDGE`, `coin_amount` for job nudges, `loan_amount` /
 * `insurance_amount` for amount nudges) kept raw so a new field never forces a
 * model change — each consumer decodes only the slice it needs.
 */
data class TierNudge(
    val nudgeName: String? = null,
    val navigationRoute: String? = null,
    val imageUrl: String? = null,
    val theme: NudgeTheme = NudgeTheme.GENERIC,
    /**
     * Whether the wire carried a **recognised** `theme` (see [NudgeTheme.fromWireOrNull]) —
     * NOT merely a non-blank string. [theme] collapses a missing/blank/unknown value to
     * [NudgeTheme.GENERIC], so this is the only signal separating "backend named a theme we
     * model" from "we defaulted". The dynamic/default nudge path uses it to decide tinting: a
     * themed dynamic icon is tinted to the theme accent, but a themeless one — OR a NEW theme
     * value this app version doesn't know yet — is shown as-is, so a full-colour backend image
     * isn't flattened by a `SrcIn` tint. Known nudges ignore this (always tinted).
     */
    val themeProvided: Boolean = false,
    val nudgeDetails: JsonObject? = null,
)

/** Visual theme of a home-screen tier nudge (`tier_nudge.theme`). */
enum class NudgeTheme {
    GENERIC,
    BENEFITS,
    MOTIVATION,
    TIER_SPECIFIC,
    ;

    companion object {
        /**
         * Parse the wire `theme` to a **recognised** [NudgeTheme], or null when it is
         * missing / blank / an unknown value this app version doesn't model. Drives
         * [TierNudge.themeProvided], so a NEW backend theme counts as "no theme" and its
         * dynamic image is shown un-tinted rather than flattened by the fallback GENERIC tint.
         */
        fun fromWireOrNull(value: String?): NudgeTheme? = when (value?.trim()?.uppercase()) {
            "GENERIC" -> GENERIC
            "BENEFITS" -> BENEFITS
            "MOTIVATION" -> MOTIVATION
            "TIER_SPECIFIC" -> TIER_SPECIFIC
            else -> null
        }

        /** As [fromWireOrNull], but collapses a missing/blank/unknown value to [GENERIC]. */
        fun fromWire(value: String?): NudgeTheme = fromWireOrNull(value) ?: GENERIC
    }
}
