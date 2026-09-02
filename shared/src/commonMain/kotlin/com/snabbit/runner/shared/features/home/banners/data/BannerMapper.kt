package com.snabbit.runner.shared.features.home.banners.data

import com.snabbit.runner.shared.features.home.banners.data.remote.dto.BannerDto
import com.snabbit.runner.shared.features.home.domain.model.Banner

/**
 * Wire → domain for home banners, lifted out of the retired
 * `BannerRepositoryImpl` unchanged: same required-field validation, same copy
 * resolution. A row missing anything required is dropped rather than failing
 * the list.
 */
internal fun List<BannerDto>.toBanners(): List<Banner> = mapNotNull { it.toBannerOrNull() }

private fun BannerDto.toBannerOrNull(): Banner? {
    val id = id?.takeIf { it.isNotBlank() } ?: return null
    val title = title?.takeIf { it.isNotBlank() } ?: return null
    val ctaLabel = buttonText?.takeIf { it.isNotBlank() } ?: return null
    val bgImageUrl = bannerBgImage?.takeIf { it.isNotBlank() } ?: return null
    val clickPath = buttonClickPath?.takeIf { it.isNotBlank() } ?: return null
    return Banner(
        id = id,
        title = title.resolveCopy(),
        subtitle = subtitle?.takeIf { it.isNotBlank() }?.resolveCopy(),
        ctaLabel = ctaLabel.resolveCopy(),
        ctaIconUrl = buttonIcon?.takeIf { it.isNotBlank() },
        bgImageUrl = bgImageUrl,
        clickPath = clickPath,
        clickArgs = clickArgs.mapValues { (_, v) -> v.resolveCopy() },
    )
}

/** Known key → default copy; anything else (already-resolved copy, or a key
 *  we don't know) passes through verbatim. */
private fun String.resolveCopy(): String = TEMP_COPY_DEFAULTS[this] ?: this

// ponytail: TEMP client-side copy map — BE's seeded home_banners config
// currently returns i18n KEYS in title/subtitle/button_text/click_args
// (e.g. "home_banner_refer_v1_title") instead of resolved copy. Until BE
// translates server-side per language_preference (open question on
// PR #487), map the known keys to their English defaults; unknown
// values pass through, so real copy from BE bypasses this map and it
// can be deleted with zero behaviour change.
private val TEMP_COPY_DEFAULTS = mapOf(
    "home_banner_refer_v1_title" to "Refer and earn upto",
    "home_banner_refer_v1_subtitle" to "₹4000",
    "home_banner_refer_v1_button_text" to "Refer Now",
    "home_banner_gold_coins_promo_title" to "Your coins are waiting",
    "home_banner_gold_coins_promo_subtitle" to "Redeem now",
    "home_banner_gold_coins_promo_button_text" to "View Rewards",
    "home_banner_gold_coins_promo_webview_title" to "Gold coins",
)
