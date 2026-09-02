package com.snabbit.runner.shared.features.tiering.presentation

import com.snabbit.runner.shared.features.tiering.domain.model.Tier

/**
 * CDN image URLs for tier badges + the Snabbit coin, mirroring the Flutter
 * `RemoteConfigAssets` tiering defaults. Presentation-layer — URLs aren't a
 * domain concern.
 *
 * TODO(tiering): source these from the KMP Remote Config mirror once the
 * feature is wired, matching the Flutter `RemoteConfigAssets` override path.
 */
internal object TierAssets {
    private const val BASE = "https://assets-expert.snabbit.com/tiering"

    /** The Snabbit-coin badge (body leading icon; also the job-nudge coin chip). */
    const val COIN_URL: String = "$BASE/coin.png"

    /** Leading icon for the job nudges (`EARLY_CHECK_IN` / `PERFECT_JOB`). */
    const val JOB_URL: String = "$BASE/job.png"

    /** Hero header image for the Snabbit Udaan intro banner. */
    const val UDAAN_BANNER_HEADER_URL: String = "$BASE/udaan_banner_header_image.png"

    /**
     * A per-nudge leading icon by file name (e.g. `benefit_loan.svg`), mirroring
     * the Flutter `RemoteConfigAssets` tiering paths. Empty [file] → empty URL
     * ([com.snabbit.design.atoms.SnabbitRemoteImage] renders nothing).
     */
    fun iconUrl(file: String): String = if (file.isEmpty()) "" else "$BASE/$file"

    /**
     * Tier badge — the header leading image and each progress milestone. Empty
     * for tiers with no dedicated tiering badge (renders nothing).
     */
    fun badgeUrl(tier: Tier): String = when (tier) {
        Tier.SILVER -> "$BASE/silver_tier.png"
        Tier.GOLD -> "$BASE/gold_tier.png"
        Tier.DIAMOND -> "$BASE/diamond_tier.png"
        Tier.PINK_DIAMOND -> "$BASE/pink_diamond_tier.png"
        Tier.BASE -> "$BASE/basic_tier.png"
        // Legacy tiers have no new-scheme badge (gated out of the tiering surfaces anyway).
        Tier.BASIC, Tier.PRO, Tier.ELITE -> ""
    }
}
