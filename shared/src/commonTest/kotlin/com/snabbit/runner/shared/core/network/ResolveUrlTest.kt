package com.snabbit.runner.shared.core.network

import io.ktor.http.HttpMethod
import kotlin.test.Test
import kotlin.test.assertEquals

/**
 * Pins [SnabbitRequest.resolveUrl] — the base-URL join that moved OUT of every
 * data source and INTO the client, so a relative request can't be resolved
 * outside `execute`'s bounded cold-start gate (the fix for the disposition-submit
 * hang). Callers pass relative paths now; this is the one place the base is joined.
 */
class ResolveUrlTest {

    private val config = NetworkConfig(
        baseUrl = "https://api.snabbit.com",
        versionCode = "1",
        onboardingUrl = "https://onboarding.snabbit.com",
    )

    private fun req(url: String, base: SnabbitBaseUrl = SnabbitBaseUrl.Api) =
        SnabbitRequest(method = HttpMethod.Get, url = url, base = base)

    @Test
    fun relative_path_joins_to_the_api_base() {
        assertEquals(
            "https://api.snabbit.com/api/v1/runners/me",
            req("/api/v1/runners/me").resolveUrl(config),
        )
    }

    @Test
    fun join_normalises_slashes_on_both_sides() {
        // Exactly one separator whether or not the path has a leading slash and
        // whether or not the base has a trailing one.
        val trailing = config.copy(baseUrl = "https://api.snabbit.com/")
        assertEquals("https://api.snabbit.com/foo", req("/foo").resolveUrl(config))
        assertEquals("https://api.snabbit.com/foo", req("foo").resolveUrl(config))
        assertEquals("https://api.snabbit.com/foo", req("/foo").resolveUrl(trailing))
        assertEquals("https://api.snabbit.com/foo", req("foo").resolveUrl(trailing))
    }

    @Test
    fun query_string_in_the_path_is_preserved() {
        assertEquals(
            "https://api.snabbit.com/api/v1/runners/me/helpline?type=late",
            req("/api/v1/runners/me/helpline?type=late").resolveUrl(config),
        )
    }

    @Test
    fun onboarding_base_is_selected_by_the_enum() {
        assertEquals(
            "https://onboarding.snabbit.com/api/v1/pan/verify",
            req("/api/v1/pan/verify", base = SnabbitBaseUrl.Onboarding).resolveUrl(config),
        )
    }

    @Test
    fun absolute_url_passes_through_verbatim_ignoring_base() {
        // A genuinely external host (an S3 presigned PUT, a CDN) must not be
        // reparented onto the API base. Case-insensitive scheme match per RFC 3986.
        val s3 = "https://bucket.s3.amazonaws.com/put?sig=abc"
        assertEquals(s3, req(s3).resolveUrl(config))
        assertEquals(s3, req(s3, base = SnabbitBaseUrl.Onboarding).resolveUrl(config))
        assertEquals(
            "HTTP://legacy.example.com/x",
            req("HTTP://legacy.example.com/x").resolveUrl(config),
        )
    }
}
