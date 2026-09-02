package com.snabbit.runner.shared.features.awol.presentation

import com.snabbit.runner.shared.features.awol.domain.AwolSnapshot

/**
 * Where the AWOL card is presented — the §9 routing table's one decision
 * point, derived (never a state machine): exactly one surface alerts at a
 * time (FR-09).
 */
enum class AwolSurface {
    /** Inactive, dismissed, or degraded (TR-06) — everything clears. */
    NONE,

    /** App in use (or in PiP — the PiP rule): the card embeds in the home page. */
    HOME_CARD,

    /**
     * Overlay flag on, and either the permission is granted (foreground
     * draw-over / over other apps) or the app is backgrounded/locked — where
     * the presenting surface is the keyguard alert (no overlay permission
     * needed) or the launcher's window path, which gates `canDrawOverlays`
     * itself before drawing.
     */
    OVERLAY,
}

/**
 * The one state both surfaces collect ([AwolViewModel.uiState]) — FR-09 is
 * structural because the routing decision is made once, here.
 */
data class AwolUiState(
    val snapshot: AwolSnapshot? = null,
    /**
     * Countdown seconds left, recomputed `deadline − now` each tick (TR-03),
     * clamped ≥ 0. Null when the payload carries no anchor — the card renders
     * without the meter, CTAs intact.
     */
    val remainingSeconds: Int? = null,
    /** The countdown hit zero — warning persists with the updated card count (FR-07). */
    val expired: Boolean = false,
    val surface: AwolSurface = AwolSurface.NONE,
    /**
     * The image the alert card renders: the server's `image_url`, else the
     * phase's RC fallback from [com.snabbit.runner.shared.features.awol.domain.AwolFlags]
     * (legacy `awol_overlay_converter` rule — breach/job → enter-hotspot,
     * re-entered → back-in-hotspot). Null → the slot keeps its placeholder.
     */
    val imageUrl: String? = null,
)

/** UI actions from either surface. */
sealed interface AwolUiIntent {
    /** "I Understand" — closes the current alert only (FR-05); episode ends on server say-so. */
    data object Dismiss : AwolUiIntent

    /** "Show Directions" (FR-04) — emits [AwolEffect.OpenDirections] when coordinates exist. */
    data object ShowDirections : AwolUiIntent
}

/** One-shot effects, handled natively/shared-side first (engine-independence rule). */
sealed interface AwolEffect {
    /** Open the maps app routed to the destination (FR-04). */
    data class OpenDirections(
        val latitude: Double,
        val longitude: Double,
        val label: String?,
    ) : AwolEffect
}
