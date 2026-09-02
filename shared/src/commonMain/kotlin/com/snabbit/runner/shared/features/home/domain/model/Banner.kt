package com.snabbit.runner.shared.features.home.domain.model

/**
 * A "More From Snabbit" banner row — BE-driven via `BannerRepository`
 * (`GET api/v1/runners/me/home_banners`), with a client-side Refer fallback
 * when the endpoint is empty or unreachable.
 */
data class Banner(
    val id: String,
    val title: String,
    val subtitle: String? = null,
    val ctaLabel: String,
    /** CTA leading-icon URL — rendered in `SnabbitButton`'s `leadingIcon` slot. */
    val ctaIconUrl: String? = null,
    /** Background image URL. Blank → the row's neutral placeholder bg shows instead. */
    val bgImageUrl: String = "",
    /**
     * Tap destination: `/route` → Flutter route (keep-host hop),
     * `decider:<key>` → client-resolved at tap time (refer / earnings gating).
     * `cmp:<key>` is reserved on the wire contract but unimplemented until a
     * CMP banner destination exists. Blank/unknown → tap no-ops.
     */
    val clickPath: String = "",
    /** Route args passed verbatim to the Flutter hop (e.g. webviewPath). */
    val clickArgs: Map<String, String> = emptyMap(),
)
