package com.snabbit.runner.shared.features.awol.domain

/**
 * The server-reported AWOL phase. The presence of the `awol` object alone
 * shows/clears the card (the phase is never a client-side state machine);
 * the phase only selects the visual variant (red breach / green re-entered /
 * yellow job-movement) and the bundled text fallbacks. Missing/unknown
 * `state` defaults to [BREACH] — parity with the legacy `AwolState.fromString`.
 */
enum class AwolPhase {
    BREACH,
    RE_ENTERED,
    JOB,
    ;

    companion object {
        fun fromWire(value: String?): AwolPhase = when (value) {
            "RE_ENTERED" -> RE_ENTERED
            "JOB" -> JOB
            else -> BREACH
        }
    }
}

/** Hotspot location — drives "Show Directions" and the hotspot tile. */
data class AwolHotspot(
    val name: String?,
    val latitude: Double?,
    val longitude: Double?,
) {
    /** FR-04: directions need coordinates; the CTA is hidden without both. */
    val hasCoordinates: Boolean get() = latitude != null && longitude != null
}

/** One consequence row (icon + resolved text) on the re-entered card. */
data class AwolConsequence(
    val iconUrl: String?,
    val text: String?,
)

/**
 * Typed read model of the `widget_data.awol` envelope — everything the two
 * surfaces (home card / overlay) render. Built exclusively by
 * `toAwolSnapshot()`; all texts arrive here already resolved (server default
 * string with `{param}` interpolation, or the bundled [AwolStrings] fallback),
 * so the UI layer never touches raw payload.
 *
 * Countdown contract (TR-03): [deadlineMillis] is the server's absolute
 * `trigger_at` anchor; the coordinator recomputes `deadline − now` every tick.
 * When `trigger_at` is absent, [remainingSeconds] is the fallback anchor
 * (receipt time + remaining). Both absent → no countdown meter, CTAs intact.
 */
data class AwolSnapshot(
    /** Server episode id — keys FR-05/06 show-once. Null → coordinator derives identity. */
    val eventId: String?,
    val phase: AwolPhase,
    /** Absolute deadline (epoch millis) parsed from `countdown.trigger_at`, or null. */
    val deadlineMillis: Long?,
    /** Meter denominator; defaults to [DEFAULT_TOTAL_SECONDS] (parity). */
    val totalSeconds: Int,
    /** Server-reported remaining at receipt — fallback anchor when [deadlineMillis] is null. */
    val remainingSeconds: Int?,
    /** Lifetime red cards; 0 → pill hidden (FR-07). */
    val redCardsTotal: Int,
    /**
     * Whether to show the penalty-rate strip (Figma §2A) — true on
     * [AwolPhase.BREACH] only. Count comes from [penaltyRateCount]; the interval is
     * derived from [totalSeconds] (the same countdown window the meter shows), so the
     * strip always agrees with the timer above it.
     */
    val showPenaltyRate: Boolean,
    /**
     * Red cards added per penalty step — the strip's "[N] 🟥" count, kept in sync
     * with the "N red cards will be added" [warningText] (both derive from the same
     * value). Read from the `red_cards` already carried in `warning_text.params`
     * (so it's correct with no backend change). Missing or 0 in the payload → null →
     * [AwolStrings] fallback (legacy hoods send no count; a literal "0" capsule is
     * never rendered).
     */
    val penaltyRateCount: Int?,
    val hotspot: AwolHotspot?,
    val consequences: List<AwolConsequence>,
    /** Server map/consequence image; null → host-injected fallback URL. */
    val imageUrl: String?,
    val titleText: String,
    /**
     * Resolved warning line. On [AwolPhase.BREACH] it is client-owned (B2/B3): built
     * from the same `warning_text.params.red_cards` per-step count as
     * [penaltyRateCount] ("Return in time or N red card(s) will be added"), falling
     * back to the generic bundled warning when that count is absent/0 — never from
     * [redCardsTotal], which is the lifetime balance shown on the pill. Non-BREACH
     * phases stay server-preferred.
     */
    val warningText: String,
    val badgeText: String,
    /** `detected_at` as epoch millis, or null. */
    val detectedAtMillis: Long?,
    /** Number of breaches this shift, or null when the server omits it. */
    val breachCount: Int?,
) {
    companion object {
        /** Legacy `CountdownData.defaultTotalSeconds` parity default. */
        const val DEFAULT_TOTAL_SECONDS = 300
    }
}
