package com.snabbit.runner.shared.features.home.banners.data.remote.dto

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * `GET api/v1/runners/me/home_banners` 200 body.
 *
 * The Updates-tab badge rides this response rather than its own endpoint, so
 * home costs one call. `notifications` is nullable by contract: null means the
 * server could not resolve that section, which is NOT the same as a resolved
 * count of zero — only zero clears the dot.
 */
@Serializable
internal data class HomeBannersResponseDto(
    val banners: List<BannerDto> = emptyList(),
    val notifications: HomeNotificationsDto? = null,
)

@Serializable
internal data class HomeNotificationsDto(
    @SerialName("unread_count") val unreadCount: Int? = null,
)

/**
 * One wire banner. Every field nullable — the repository owns validation
 * (blank/missing required keys → the row is skipped, the rest render), so a
 * partially-bad payload never fails the whole list.
 */
@Serializable
internal data class BannerDto(
    val id: String? = null,
    val title: String? = null,
    val subtitle: String? = null,
    @SerialName("button_text") val buttonText: String? = null,
    @SerialName("button_icon") val buttonIcon: String? = null,
    @SerialName("banner_bg_image") val bannerBgImage: String? = null,
    @SerialName("button_click_path") val buttonClickPath: String? = null,
    @SerialName("click_args") val clickArgs: Map<String, String> = emptyMap(),
)
