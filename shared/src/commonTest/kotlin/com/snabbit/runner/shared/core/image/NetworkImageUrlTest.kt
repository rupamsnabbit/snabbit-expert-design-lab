package com.snabbit.runner.shared.core.image

import kotlin.test.Test
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/**
 * Pins the [isNetworkImageUrl] allow-list (test-plan SEC-04).
 *
 * `buildSnabbitImageLoader` registers the Ktor fetcher with `.components { add(…) }`,
 * which *augments* Coil's defaults rather than replacing them — `FileUriFetcher` and
 * `ContentUriFetcher` stay registered. Every URL reaching an image composable is
 * server- or Remote-Config-supplied, so this allow-list is the only thing stopping a
 * hostile `file://` / `content://` payload from rendering local content full-bleed —
 * including on the AWOL alert over the lock screen.
 */
class NetworkImageUrlTest {

    @Test
    fun http_and_https_are_allowed() {
        assertTrue(isNetworkImageUrl("https://cdn.snabbit.com/awol/enter_hotspot.jpg"))
        // http stays allowed: the local E2E stack and staging ephemeral envs serve
        // assets cleartext; release blocks those at the transport layer instead.
        assertTrue(isNetworkImageUrl("http://10.0.2.2:8000/icon.png"))
    }

    @Test
    fun scheme_match_is_case_insensitive() {
        assertTrue(isNetworkImageUrl("HTTPS://cdn.snabbit.com/a.png"))
        assertTrue(isNetworkImageUrl("HtTp://cdn.snabbit.com/a.png"))
    }

    @Test
    fun local_schemes_are_rejected() {
        assertFalse(isNetworkImageUrl("file:///data/data/com.snabbit.runner/shared_prefs/FlutterSharedPreferences.xml"))
        assertFalse(isNetworkImageUrl("content://com.android.providers.media.documents/document/image%3A1"))
        assertFalse(isNetworkImageUrl("android.resource://com.snabbit.runner/drawable/ic_launcher"))
        assertFalse(isNetworkImageUrl("data:image/png;base64,iVBORw0KGgo="))
    }

    @Test
    fun schemeless_relative_and_empty_values_are_rejected() {
        assertFalse(isNetworkImageUrl(""))
        assertFalse(isNetworkImageUrl("/assets/icon.png"))
        assertFalse(isNetworkImageUrl("cdn.snabbit.com/a.png"))
        // No leading-whitespace bypass — the check is a prefix match, not a `contains`.
        assertFalse(isNetworkImageUrl(" https://cdn.snabbit.com/a.png"))
    }
}
