package com.snabbit.runner.shared.features.awol.domain

import com.snabbit.runner.shared.core.localization.LocalizationStore

/**
 * Bundled English fallbacks for the AWOL surfaces — the KMP analogue of the
 * Dart `AwolStrings` defaults (`lib/utils/awol_strings.dart`), used when the
 * payload omits a text model (FR-17 mapper fallback).
 *
 * English-interim decision (TRD §10, 2026-07-09): v1 renders the payload's
 * `default` string (with `{param}` interpolation) or these fallbacks — parity
 * with today's native overlay, whose isolate has no LanguageProvider. A class
 * (not an object) so the shared server-driven strings layer can swap a
 * localized instance in later as a constructor change, no rework — the
 * `ShiftLoginStrings` convention.
 */
class AwolStrings(
    // Breach
    val breachTitle: String = "Please return to hotspot within",
    val breachWarning: String =
        "You will face a penalty if you don't return before the timer expires.",
    val breachBadge: String = "HOTSPOT BREACH",
    // Re-entered
    val reEnteredTitle: String = "Re-entered hotspot",
    val reEnteredWarning: String =
        "You exited the hotspot once today. Repeated breaches may result in:",
    val reEnteredBadge: String = "BACK IN HOTSPOT",
    // Job AWOL (movement required)
    val jobTitle: String = "Please go to the job location",
    val jobWarning: String = "You'll receive a penalty if you don't start moving soon",
    val jobBadge: String = "MOVEMENT REQUIRED",
    // Red-card pill — MUST resolve singular/plural (§2A: "1 Red Card", never "1 Red Cards")
    val redCardReceivedSingular: String = "RED CARD RECEIVED",
    val redCardReceivedPlural: String = "RED CARDS RECEIVED",
    // B2/B3 breach warning pieces — "Return in time or [count] red card(s) will be added".
    // Client-owned: derived from `warning_text.params.red_cards` (the per-step count
    // also feeding the penalty strip), never the payload's rendered warning_text.
    val redCardsPendingPrefix: String = "Return in time or",
    val redCardsPendingSuffix: String = "will be added",
    val redCardUnitSingular: String = "red card",
    val redCardUnitPlural: String = "red cards",
    // Penalty-rate strip pieces — two red capsules ("[count] 🟥" · [connector] · "[interval] ⏰",
    // §2A). Shown on BREACH only. [penaltyRateCount] is the fallback count when the payload
    // carries none; the interval is always derived from the countdown window and formatted
    // via [penaltyRateIntervalOf].
    val penaltyRateCount: String = "1",
    val penaltyRateConnector: String = "for every",
    val penaltyRateIntervalUnitSingular: String = "Minute",
    val penaltyRateIntervalUnitPlural: String = "Minutes",
    // Common
    val timeLeftLabel: String = "TIME LEFT",
    val showDirections: String = "Show Directions",
    val understood: String = "I Understand",
    val hotspotTileTitle: String = "Your Hotspot",
    val hotspotTileMap: String = "Map",
    /** Suffix of the tile's distance line ("3.2 km away"); the number is host-computed. */
    val hotspotDistanceAwaySuffix: String = "away",
) {
    /** Per-phase title fallback. */
    fun titleFor(phase: AwolPhase): String = when (phase) {
        AwolPhase.BREACH -> breachTitle
        AwolPhase.RE_ENTERED -> reEnteredTitle
        AwolPhase.JOB -> jobTitle
    }

    /**
     * Per-phase warning fallback. The BREACH warning is handled upstream by the
     * mapper (client-owned B2/B3 derivation, so the mapper never calls this for
     * BREACH); its arm here remains only as the exhaustive-`when` fallback.
     */
    fun warningFor(phase: AwolPhase): String = when (phase) {
        AwolPhase.BREACH -> breachWarning
        AwolPhase.RE_ENTERED -> reEnteredWarning
        AwolPhase.JOB -> jobWarning
    }

    /** Per-phase badge fallback. */
    fun badgeFor(phase: AwolPhase): String = when (phase) {
        AwolPhase.BREACH -> breachBadge
        AwolPhase.RE_ENTERED -> reEnteredBadge
        AwolPhase.JOB -> jobBadge
    }

    /**
     * Singular/plural red-card-received label — single source of truth, parity
     * with Dart `AwolStrings.redCardReceivedLabel`.
     */
    fun redCardReceivedLabel(count: Int): String =
        if (count == 1) redCardReceivedSingular else redCardReceivedPlural

    /**
     * Penalty-rate interval capsule — "30 Minutes" / "1 Minute". [mins] is the
     * countdown window the meter is showing (p75 on round 1, step interval after),
     * so the strip's interval always matches the timer.
     */
    fun penaltyRateIntervalOf(mins: Int): String =
        "$mins ${if (mins == 1) penaltyRateIntervalUnitSingular else penaltyRateIntervalUnitPlural}"

    /**
     * B2/B3 BREACH warning when red cards are pending — "Return in time or
     * 1 red card will be added" / "… 3 red cards will be added" (singular/
     * plural resolved here, single source of truth). The mapper calls this
     * with `warning_text.params.red_cards` (the per-step count also feeding
     * the penalty strip); a missing/0 count never reaches here (generic
     * [breachWarning] applies instead).
     */
    fun redCardsPendingWarningOf(count: Int): String =
        "$redCardsPendingPrefix $count " +
            (if (count == 1) redCardUnitSingular else redCardUnitPlural) +
            " $redCardsPendingSuffix"
}

/**
 * Server-driven localization overlay for [AwolStrings]. Because [AwolStrings] is a plain class
 * (no `copy()`), this constructs a NEW instance from `store.getMessage("<key>", <englishDefault>)`
 * per field (absent key → English, behaviour-preserving). The penalty-rate cadence pieces are a
 * fixed product constant (never server-driven) — omitted, so they keep their constructor defaults.
 *
 * Apply where Koin is guaranteed started; NEVER bake into the AwolViewModel Koin `single` —
 * `getMessage` is a non-reactive snapshot read and the store is empty at container-build, so a
 * one-shot bake would freeze English forever. The VM re-localizes per snapshot; the composable
 * hosts pass a fresh localized instance.
 */
fun AwolStrings.localized(store: LocalizationStore): AwolStrings = AwolStrings(
    breachTitle = store.getMessage("awol.title", breachTitle),
    breachWarning = store.getMessage("awol.penalty_warning", breachWarning),
    breachBadge = store.getMessage("awol.badge_hotspot_breach", breachBadge),
    reEnteredTitle = store.getMessage("awol_alert.re_entered_title", reEnteredTitle),
    reEnteredWarning = store.getMessage("awol_alert.re_entered_warning", reEnteredWarning),
    reEnteredBadge = store.getMessage("awol_alert.badge_back_in_hotspot", reEnteredBadge),
    jobTitle = store.getMessage("awol.job_title", jobTitle),
    jobWarning = store.getMessage("awol.job_warning", jobWarning),
    jobBadge = store.getMessage("awol.badge_movement_required", jobBadge),
    redCardReceivedSingular =
        store.getMessage("awol_alert.red_card_received_singular", redCardReceivedSingular),
    redCardReceivedPlural =
        store.getMessage("awol_alert.red_cards_received_plural", redCardReceivedPlural),
    timeLeftLabel = store.getMessage("awol.timer_label", timeLeftLabel),
    showDirections = store.getMessage("awol.cta_show_directions", showDirections),
    understood = store.getMessage("awol.cta_i_understand", understood),
    hotspotTileTitle = store.getMessage("home.your_hotspot", hotspotTileTitle),
    hotspotTileMap = store.getMessage("common.action_map", hotspotTileMap),
    hotspotDistanceAwaySuffix =
        store.getMessage("awol.distance_away_suffix", hotspotDistanceAwaySuffix),
)
