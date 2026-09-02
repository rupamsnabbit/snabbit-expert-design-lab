package com.snabbit.runner.shared.core.image

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import coil3.compose.AsyncImage

/**
 * The module's one remote-image entry point (core seam — app-generic, never a
 * feature-scoped copy). The Design System has no image component, so this thin
 * Coil wrapper is the sanctioned rendering path for CDN/server image URLs;
 * feature composables must not import `coil3` directly.
 *
 * Renders through the process-wide [coil3.SingletonImageLoader], installed by
 * the host at startup ([com.snabbit.runner.shared.core.KmpBootstrap] on
 * Android via [buildSnabbitImageLoader]). Tests override it with
 * `setSingletonImageLoaderFactory` + a `FakeImageLoaderEngine` so goldens stay
 * deterministic.
 *
 * Degrades gracefully by drawing nothing — null/blank [url], a non-network
 * scheme, load in flight, or load failure all leave the caller's own
 * placeholder block visible (callers keep their background/clip exactly as
 * before the loader existed).
 *
 * **Network schemes only.** Every URL reaching here is server-supplied
 * (`widget_data.awol.image_url`, Remote Config asset fallbacks,
 * `SupportOption.iconUrl`), and [buildSnabbitImageLoader] registers the Ktor
 * fetcher with `.components { add(...) }`, which *augments* Coil's defaults
 * rather than replacing them — so `FileUriFetcher` and `ContentUriFetcher`
 * stay registered. Without this gate a compromised backend could return
 * `file:///data/data/com.snabbit.runner/…` or `content://<exported provider>/…`
 * and have local content rendered full-bleed on the AWOL alert — including
 * over the lock screen and over other apps. Blocking at the one seam every
 * feature must route through is cheaper than trusting each payload.
 */
@Composable
fun RemoteImage(
    url: String?,
    contentDescription: String?,
    modifier: Modifier = Modifier,
    contentScale: ContentScale = ContentScale.Crop,
) {
    if (url.isNullOrBlank()) return
    if (!isNetworkImageUrl(url)) return
    AsyncImage(
        model = url,
        contentDescription = contentDescription,
        modifier = modifier,
        contentScale = contentScale,
    )
}

/**
 * True only for `http://` / `https://` URLs (scheme match is case-insensitive,
 * per RFC 3986). `http` stays allowed because the local E2E stack and the
 * staging ephemeral env serve assets over cleartext; release builds block
 * those at the transport layer via the network-security-config, so this gate
 * does not need to duplicate that policy — it exists to exclude the *local*
 * schemes (`file:`, `content:`, `android.resource:`, `data:`).
 */
internal fun isNetworkImageUrl(url: String): Boolean =
    url.startsWith("http://", ignoreCase = true) ||
        url.startsWith("https://", ignoreCase = true)
