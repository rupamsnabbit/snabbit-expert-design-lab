package com.snabbit.runner.shared.features.home.banners

import com.snabbit.runner.shared.features.home.banners.data.remote.dto.BannerDto
import com.snabbit.runner.shared.features.home.banners.data.toBanners
import kotlin.test.Test
import kotlin.test.assertEquals

/**
 * Row validation and copy resolution, carried over from the retired
 * `BannerRepositoryImplTest` when the mapping moved into `BannerMapper`. The
 * logic is unchanged, so these are the same assertions against the free
 * function.
 */
class BannerMapperTest {

    private fun dto(
        id: String? = "refer_v1",
        title: String? = "Refer and earn upto",
        subtitle: String? = "₹4000",
        buttonText: String? = "Refer Now",
        buttonIcon: String? = null,
        bannerBgImage: String? = "https://cdn.example.com/bg.png",
        buttonClickPath: String? = "/referral-home",
        clickArgs: Map<String, String> = emptyMap(),
    ) = BannerDto(id, title, subtitle, buttonText, buttonIcon, bannerBgImage, buttonClickPath, clickArgs)

    @Test fun mapsValidDtoToDomain_fieldForField() {
        val banner = listOf(
            dto(buttonIcon = "https://cdn.example.com/coin.png", clickArgs = mapOf("k" to "v")),
        ).toBanners().single()

        assertEquals("refer_v1", banner.id)
        assertEquals("Refer and earn upto", banner.title)
        assertEquals("₹4000", banner.subtitle)
        assertEquals("Refer Now", banner.ctaLabel)
        assertEquals("https://cdn.example.com/coin.png", banner.ctaIconUrl)
        assertEquals("https://cdn.example.com/bg.png", banner.bgImageUrl)
        assertEquals("/referral-home", banner.clickPath)
        assertEquals(mapOf("k" to "v"), banner.clickArgs)
    }

    @Test fun skipsRowsMissingRequiredKeys_keepsValidRows() {
        val banners = listOf(
            dto(id = null),                    // dropped — no id
            dto(id = "ok_1"),                  // kept
            dto(id = "no_title", title = " "), // dropped — blank title
            dto(id = "no_cta", buttonText = null),        // dropped
            dto(id = "no_bg", bannerBgImage = ""),        // dropped
            dto(id = "no_path", buttonClickPath = null),  // dropped
            dto(id = "ok_2"),                  // kept — order preserved
        ).toBanners()

        assertEquals(listOf("ok_1", "ok_2"), banners.map { it.id })
    }

    @Test fun blankOptionalFields_normalizedToNull() {
        val banner = listOf(dto(subtitle = "", buttonIcon = " ")).toBanners().single()

        assertEquals(null, banner.subtitle)
        assertEquals(null, banner.ctaIconUrl)
    }

    @Test fun i18nKeys_resolveToTempDefaults_realCopyPassesThrough() {
        // TEMP map (see BannerMapper.TEMP_COPY_DEFAULTS): BE currently sends
        // i18n keys — known keys resolve to English defaults; anything else
        // (already-resolved copy / unknown keys) passes through verbatim.
        val banners = listOf(
            dto(
                id = "refer_v1",
                title = "home_banner_refer_v1_title",
                subtitle = "home_banner_refer_v1_subtitle",
                buttonText = "home_banner_refer_v1_button_text",
                clickArgs = mapOf("title" to "home_banner_gold_coins_promo_webview_title"),
            ),
            dto(id = "real_copy", title = "Real title", subtitle = "unknown_key_xyz"),
        ).toBanners()

        assertEquals("Refer and earn upto", banners[0].title)
        assertEquals("₹4000", banners[0].subtitle)
        assertEquals("Refer Now", banners[0].ctaLabel)
        assertEquals(mapOf("title" to "Gold coins"), banners[0].clickArgs)
        assertEquals("Real title", banners[1].title)         // resolved copy untouched
        assertEquals("unknown_key_xyz", banners[1].subtitle) // unknown key passes through
    }

    @Test fun emptyListMapsToEmpty() {
        assertEquals(emptyList(), emptyList<BannerDto>().toBanners())
    }
}
