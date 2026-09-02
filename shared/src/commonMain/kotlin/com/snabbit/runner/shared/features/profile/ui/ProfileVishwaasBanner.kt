package com.snabbit.runner.shared.features.profile.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import coil3.compose.AsyncImage
import com.snabbit.runner.shared.core.image.isNetworkImageUrl

/**
 * The Vishwaas rate-card image banner (drawer parity — `VishwaasDrawerBanner`): a
 * full-width remote image (per-language, from the RC config) that on tap opens the
 * Vishwaas rate-card webview. Rendered only when the ViewModel resolved a URL (the
 * 4-condition gate passed); a failed image load simply shows nothing.
 *
 * Coil [AsyncImage] scaled to full width by its natural aspect ratio, lightly
 * rounded to sit with the profile's cards. `commonMain` / iOS-safe.
 */
@Composable
fun ProfileVishwaasBanner(
    imageUrl: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    // http(s) only — same gate as core/image RemoteImage. The URL is Remote-Config
    // supplied and Coil's default file:/content: fetchers stay registered alongside our
    // Ktor one, so a local-scheme value would paint local content full-width here.
    // Rejected URLs render nothing, matching the "a failed load simply shows nothing" rule.
    if (!isNetworkImageUrl(imageUrl)) return
    AsyncImage(
        model = imageUrl,
        contentDescription = null,
        contentScale = ContentScale.FillWidth,
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(ProfileTileDefaults.NudgeCardRadius))
            .clickable(onClick = onClick),
    )
}
