package com.snabbit.runner.shared.features.awol.data

import com.snabbit.runner.shared.core.Logger
import com.snabbit.runner.shared.features.awol.domain.AwolConsequence
import com.snabbit.runner.shared.features.awol.domain.AwolHotspot
import com.snabbit.runner.shared.features.awol.domain.AwolPhase
import com.snabbit.runner.shared.features.awol.domain.AwolSnapshot
import com.snabbit.runner.shared.features.awol.domain.AwolStrings
import com.snabbit.runner.shared.features.job.data.asDoubleOrNull
import com.snabbit.runner.shared.features.job.data.asIntOrNull
import com.snabbit.runner.shared.features.job.data.asStringOrNull
import com.snabbit.runner.shared.features.job.data.obj
import com.snabbit.runner.shared.features.job.domain.JobClock
import com.snabbit.runner.shared.core.runnerstate.RunnerState
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.contentOrNull

private const val TAG = "AwolStateMapper"

/**
 * Whether the envelope carries an AWOL payload (`widget_data.awol` present as
 * an object). The generic launcher's store-driven trigger — deterministic on
 * the emission itself, so a launch decision never depends on another
 * collector (the coordinator) having processed the same emission first.
 */
fun RunnerState?.hasAwolPayload(): Boolean = this?.widgetData?.obj("awol") != null

/**
 * Pure projection from the bridged `current_state` envelope to an [AwolSnapshot].
 * The `awol` object rides `widget_data` under its own key regardless of the
 * envelope's `widget_name` (legacy: `widgetInfo.data['awol']`), so this reads
 * only that slice and ignores the rest — sibling of [com.snabbit.runner.shared.features.job.data.toJob].
 *
 * Fallback contract (TRD §9 "Mapper parsing rules", TR-02) — never throws:
 *  - whole `awol` key missing/not an object → null (inactive — all surfaces clear)
 *  - `event_id` missing → null (coordinator derives episode identity, legacy behaviour)
 *  - `state` → NOT a client state machine; selects visual variant + text fallbacks only
 *  - `countdown.trigger_at` missing/unparseable → null deadline (no meter; CTAs intact; logged)
 *  - `countdown.total_seconds` missing → 300 (parity default)
 *  - `red_cards_total` missing → 0 (pill hidden)
 *  - penalty-rate strip → shown on BREACH only (Figma §2A); count = `warning_text.params.red_cards`
 *    (present today, so the count is dynamic without a backend change), interval is derived
 *    from the countdown window (`total_seconds`) in the UI so it matches the meter. Count
 *    missing or 0 → null, so the UI shows the bundled [AwolStrings] fallback.
 *  - `hotspot` lat/lng missing → carried as null (Show Directions hidden)
 *  - texts missing → [AwolStrings] fallbacks (FR-17, English-interim)
 *  - BREACH `warning_text.default` → IGNORED (B2/B3): the warning is client-owned,
 *    derived from `warning_text.params.red_cards` — the same per-step "will be added"
 *    count feeding the strip — n ≥ 1 → "Return in time or n red card(s) will be
 *    added", missing/0 → the generic bundled breach warning (legacy hoods send no
 *    params). `red_cards_total` (the lifetime received balance) feeds only the pill,
 *    never the warning. Non-BREACH warnings stay server-preferred. The badge stays
 *    server-preferred on every phase.
 */
fun RunnerState?.toAwolSnapshot(
    clock: JobClock,
    logger: Logger,
    strings: AwolStrings = AwolStrings(),
): AwolSnapshot? {
    val awol = this?.widgetData?.obj("awol") ?: return null
    val phase = AwolPhase.fromWire(awol["state"].asStringOrNull())

    val countdown = awol.obj("countdown")
    val triggerAtIso = countdown?.get("trigger_at").asStringOrNull()
    val deadlineMillis = triggerAtIso?.let { iso ->
        clock.parseEpochMillis(iso).also { parsed ->
            if (parsed == null) logger.w(TAG, "unparseable trigger_at: $iso")
        }
    }
    if (triggerAtIso == null) {
        logger.d(TAG, "awol payload without trigger_at — meter falls back to remaining_seconds")
    }

    val detectedAtIso = awol["detected_at"].asStringOrNull()?.takeIf { it.isNotEmpty() }

    // Pending count = "red cards that will be added" this penalty step — already
    // carried in the warning's params, so it's dynamic with no backend change. Feeds
    // the penalty strip AND the client-owned BREACH warning below, so the two always
    // agree; 0 is normalized to null so both surfaces fall back to bundled copy
    // instead of rendering "0" (the strip's interval is derived from the countdown
    // window, see AwolAlertContent).
    val pendingRedCards = awol.obj("warning_text")?.obj("params")
        ?.get("red_cards").asIntOrNull()?.takeIf { it > 0 }

    // B2/B3: the BREACH warning is client-owned — derived from the pending per-step
    // count above, never the payload's rendered warning_text. `red_cards_total` is the
    // lifetime received balance ("N RED CARDS RECEIVED" pill) and feeds only the pill.
    val redCardsTotal = awol["red_cards_total"].asIntOrNull() ?: 0
    val warningText = if (phase == AwolPhase.BREACH) {
        if (pendingRedCards != null) strings.redCardsPendingWarningOf(pendingRedCards)
        else strings.breachWarning
    } else {
        readText(awol.obj("warning_text")) ?: strings.warningFor(phase)
    }

    return AwolSnapshot(
        eventId = awol["event_id"].asStringOrNull()?.takeIf { it.isNotEmpty() },
        phase = phase,
        deadlineMillis = deadlineMillis,
        totalSeconds = countdown?.get("total_seconds").asIntOrNull()
            ?: AwolSnapshot.DEFAULT_TOTAL_SECONDS,
        remainingSeconds = countdown?.get("remaining_seconds").asIntOrNull(),
        redCardsTotal = redCardsTotal,
        showPenaltyRate = phase == AwolPhase.BREACH,
        penaltyRateCount = pendingRedCards,
        hotspot = readHotspot(awol.obj("hotspot")),
        consequences = readConsequences(awol["consequences"] as? JsonArray),
        imageUrl = awol["image_url"].asStringOrNull()?.takeIf { it.isNotEmpty() },
        titleText = readText(awol.obj("title")) ?: strings.titleFor(phase),
        warningText = warningText,
        badgeText = readText(awol.obj("badge_text")) ?: strings.badgeFor(phase),
        detectedAtMillis = detectedAtIso?.let { clock.parseEpochMillis(it) },
        breachCount = awol["breach_count"].asIntOrNull(),
    )
}

/**
 * Text model `{key, default, params}` → the `default` string with `{{param}}`
 * interpolation (English-interim decision, TRD §10 2026-07-09 — no catalog;
 * parity with today's native overlay rendering `defaultText` directly).
 * Placeholders are DOUBLE-braced (`{{param}}`) to match the app-wide contract:
 * the server templates (e.g. `awol_re_entered_warning`) use `{{...}}`, and Dart's
 * `LanguageProvider.getFormattedMessage` replaces `{{key}}`. Single-brace
 * replacement left the outer braces behind, rendering e.g. `{once}`.
 * Blank/missing `default` → null so the caller applies the bundled fallback.
 */
internal fun readText(model: JsonObject?): String? {
    val template = model?.get("default").asStringOrNull()?.takeIf { it.isNotBlank() } ?: return null
    val params = model.obj("params") ?: return template
    return params.entries.fold(template) { acc, (key, value) ->
        // contentOrNull (not content) so a JSON-null param is skipped — leaving
        // the placeholder untouched — instead of interpolating the literal
        // "null" (JsonNull is itself a JsonPrimitive). Mirrors the Dart mapper.
        val replacement = (value as? JsonPrimitive)?.contentOrNull ?: return@fold acc
        acc.replace("{{$key}}", replacement)
    }
}

private fun readHotspot(hotspot: JsonObject?): AwolHotspot? {
    if (hotspot == null) return null
    return AwolHotspot(
        name = hotspot["name"].asStringOrNull(),
        latitude = hotspot["latitude"].asDoubleOrNull(),
        longitude = hotspot["longitude"].asDoubleOrNull(),
    )
}

private fun readConsequences(consequences: JsonArray?): List<AwolConsequence> {
    if (consequences == null) return emptyList()
    return consequences.mapNotNull { element ->
        val row = element as? JsonObject ?: return@mapNotNull null
        AwolConsequence(
            iconUrl = row["icon_url"].asStringOrNull(),
            text = readText(row.obj("text")),
        )
    }
}
