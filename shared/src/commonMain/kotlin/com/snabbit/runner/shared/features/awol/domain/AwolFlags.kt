package com.snabbit.runner.shared.features.awol.domain

/**
 * Host-injected remote flags (TR-07). `:shared` has no Remote Config client —
 * hosts read Firebase RC and push an instance down (Android: over the AWOL
 * config channel). **Nothing pushed = these defaults = the feature ships
 * dark**: overlay off, job-AWOL kill-switch off, permission-ask mandatory on.
 */
data class AwolFlags(
    /** Over-other-apps alert kill-switch. OFF until RC pushes true. */
    val overlayEnabled: Boolean = false,
    /**
     * In-app HOME_CARD kill-switch (`expert_enable_awol_v2_home_card`). OFF until
     * RC pushes true. The KMP coordinator still routes HOME_CARD on foreground;
     * this decides whether the native Compose home mounts the AWOL card at all —
     * flag off = no card, no distance-tracker GPS (the sibling of [overlayEnabled]
     * for the in-app surface).
     */
    val homeCardEnabled: Boolean = false,
    /** Whole job-AWOL surface kill-switch (FR-16). Other dev's scope; carried for completeness. */
    val jobAwolEnabled: Boolean = false,
    /** FR-11: whether the home-screen overlay-permission ask blocks or is skippable. */
    val permissionAskMandatory: Boolean = true,
    /**
     * RC-configured fallback map-image URLs (§10 audit: the legacy fallbacks are
     * RC links — `RemoteConfigAssets.awolEnterHotspot/awolBackInHotspot` — not
     * bundled assets). Null → image slot renders its placeholder.
     */
    val fallbackBreachImageUrl: String? = null,
    val fallbackReEnteredImageUrl: String? = null,
)
