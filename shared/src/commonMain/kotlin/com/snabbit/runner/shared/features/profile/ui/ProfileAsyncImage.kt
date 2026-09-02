package com.snabbit.runner.shared.features.profile.ui

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.dp
import coil3.compose.AsyncImage
import com.snabbit.runner.shared.core.image.isNetworkImageUrl
import com.snabbit.runner.shared.resources.Res
import com.snabbit.runner.shared.resources.profile_avatar_placeholder
import org.jetbrains.compose.resources.painterResource

/**
 * The runner's profile photo — a cached Coil [AsyncImage] loaded from [photoUrl],
 * clipped to a circle. The expert-avatar placeholder covers every non-data state:
 * while loading, on load failure, and when there's no usable URL. commonMain / iOS-safe.
 *
 * Uses Coil directly (not the core [com.snabbit.runner.shared.core.image.RemoteImage]
 * seam) because it needs the loading/error/empty painter states, which that shared
 * wrapper deliberately omits — keeping this state handling local to the profile image.
 */
@Composable
fun ProfileAsyncImage(
    photoUrl: String?,
    modifier: Modifier = Modifier,
    diameter: Int = 72,
) {
    val placeholder = painterResource(Res.drawable.profile_avatar_placeholder)
    // http(s) only — same gate as core/image RemoteImage. `photoUrl` comes off
    // `runners/me`, and Coil's default file:/content: fetchers stay registered next to
    // our Ktor one, so a local-scheme URL would render local content as the runner's
    // photo. Rejected URLs (null / blank / local-scheme) degrade to the placeholder,
    // exactly like a missing URL does.
    if (photoUrl.isNullOrBlank() || !isNetworkImageUrl(photoUrl)) {
        Image(
            painter = placeholder,
            contentDescription = null,
            modifier = modifier.size(diameter.dp).clip(CircleShape),
            contentScale = ContentScale.Crop,
        )
        return
    }
    AsyncImage(
        model = photoUrl,
        contentDescription = null,
        modifier = modifier.size(diameter.dp).clip(CircleShape),
        contentScale = ContentScale.Crop,
        placeholder = placeholder, // shown while loading
        error = placeholder,       // shown on load failure
        fallback = placeholder,    // defensive — model is already non-blank + network here
    )
}
