package com.snabbit.runner.shared.features.gamification.data

import com.snabbit.runner.shared.features.gamification.domain.model.CtaOverride
import com.snabbit.runner.shared.features.gamification.domain.model.GamificationState
import com.snabbit.runner.shared.features.gamification.domain.model.NudgeKind
import com.snabbit.runner.shared.features.gamification.domain.model.NudgeLabel
import com.snabbit.runner.shared.features.gamification.domain.model.OutcomeStatus
import com.snabbit.runner.shared.features.gamification.domain.model.PostActionOutcome
import com.snabbit.runner.shared.features.gamification.domain.model.PreActionNudge
import com.snabbit.runner.shared.features.gamification.domain.model.SheetWarning
import kotlinx.datetime.Instant
import kotlinx.datetime.LocalDateTime
import kotlinx.datetime.TimeZone
import kotlinx.datetime.toInstant
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.contentOrNull

/**
 * Pure, throw-free parsing of the gamification slices of the `current_state`
 * envelope — the KMP port of Dart `GamificationManager` + the gamification model
 * `tryFromMap` factories.
 *
 * Decoding is done by hand off [JsonObject] (the house pattern — see
 * `ShiftProjector` / `LunchProjector`) rather than `@Serializable` DTOs, because
 * every field accepts **both** camelCase (LLD) and snake_case (Python) keys and
 * malformed rows must be dropped individually rather than failing the whole
 * decode. No method throws; a malformed row is skipped and reported via
 * [onError] (wired to the crash reporter by the projector).
 *
 * Stateless and side-effect-free apart from [onError]; [nowMs] is passed in so
 * staleness is testable with a fake clock.
 */
class GamificationParser(
    private val onError: (Throwable, String) -> Unit = { _, _ -> },
) {

    /**
     * Fold the whole envelope into a [GamificationState].
     *
     * - `pre_action_nudges` is read from `widget_data` first, then the top-level
     *   envelope (mirrors Dart `parseNudges`).
     * - `sheet_warnings` / `gold_coins_total` / `red_cards_total` are top-level
     *   envelope siblings.
     * - `gold_coins_total` / `red_cards_total` **carry forward from [previous]**
     *   when the envelope omits them — Flutter special-cases exactly these two
     *   totals with `?? previous` (`runner_rt_data.dart`), because MQTT/widget
     *   envelopes routinely drop the gamification siblings; without the carry the
     *   coin / red-card pills would flicker to 0 on any such envelope. A real `0`
     *   still overrides (absent ≠ zero). Everything else reparses fresh, as it
     *   does on the Flutter side. Stays pure — [previous] is passed in, not held.
     * - CTA overrides are flattened from the nudges into a lowercase-keyed,
     *   last-wins map (mirrors Dart `resolveCtaOverridesFromNudges`).
     */
    fun parseState(
        envelope: JsonObject?,
        nowMs: Long,
        previous: GamificationState = GamificationState.EMPTY,
    ): GamificationState {
        if (envelope == null) return previous
        val nudges = parseNudges(envelope)
        val warnings = parseSheetWarnings(envelope, nowMs)
        return GamificationState(
            nudges = nudges,
            sheetWarnings = warnings,
            ctaOverrides = resolveCtaOverrides(nudges),
            coinsTotal = envelope.dualInt("gold_coins_total", "goldCoinsTotal") ?: previous.coinsTotal,
            redCardsTotal = envelope.dualInt("red_cards_total", "redCardsTotal") ?: previous.redCardsTotal,
        )
    }

    /** `pre_action_nudges` from `widget_data` first, else the envelope top level. */
    fun parseNudges(envelope: JsonObject): List<PreActionNudge> {
        val widgetData = envelope["widget_data"] as? JsonObject
        val raw = widgetData?.dualArray("pre_action_nudges", "preActionNudges")
            ?: envelope.dualArray("pre_action_nudges", "preActionNudges")
            ?: return emptyList()
        return raw.mapObjects { nudgeFromObject(it) }
    }

    /** Top-level `sheet_warnings`; drops rows whose `expires_at` is before [nowMs]. */
    fun parseSheetWarnings(envelope: JsonObject, nowMs: Long): List<SheetWarning> {
        val raw = envelope.dualArray("sheet_warnings", "sheetWarnings") ?: return emptyList()
        return raw.mapObjects { obj ->
            val warning = sheetWarningFromObject(obj) ?: return@mapObjects null
            if (isStale(warning.expiresAtMs, nowMs)) null else warning
        }
    }

    /** Reads a `post_action_outcome` object (per-action response); null when absent/invalid. */
    fun parsePostActionOutcome(response: JsonObject?): PostActionOutcome? {
        if (response == null) return null
        val obj = (response["post_action_outcome"] ?: response["postActionOutcome"])
            as? JsonObject ?: return null
        return postActionOutcomeFromObject(obj)
    }

    // ── row mappers (port of the Dart `tryFromMap` factories) ──────────────────

    private fun nudgeFromObject(map: JsonObject): PreActionNudge? = guard("PreActionNudge") {
        val lifecycle = map.dualString("lifecycle_action_type", "lifecycleActionType").orEmpty()
        val kindRaw = map.dualString("nudge_kind", "nudgeKind").orEmpty()
        val iconUrl = map.dualString("icon_url", "iconUrl").orEmpty()
        val label = labelFrom(map["label"], legacyTitle = map.stringOrNull("title"))
        // Same validity gate as Dart `PreActionNudge.tryFromMap`.
        if (lifecycle.isEmpty() || kindRaw.isEmpty() || iconUrl.isEmpty() || !label.isValid) {
            return@guard null
        }
        PreActionNudge(
            lifecycleActionType = lifecycle,
            nudgeKind = NudgeKind.fromRaw(kindRaw),
            iconUrl = iconUrl,
            label = label,
            goldCoins = map.dualInt("gold_coins", "goldCoins"),
            redCards = map.dualInt("red_cards", "redCards"),
            expiresAtMs = parseIsoMillis(map.dualString("expires_at", "expiresAt")),
            ctaOverrides = ctaOverrideList(map.dualElement("cta_overrides", "ctaOverrides")),
        )
    }

    private fun sheetWarningFromObject(map: JsonObject): SheetWarning? = guard("SheetWarning") {
        val lifecycle = map.dualString("lifecycle_action_type", "lifecycleActionType").orEmpty()
        if (lifecycle.isEmpty()) return@guard null
        SheetWarning(
            lifecycleActionType = lifecycle,
            ctaOverrides = ctaOverrideList(map.dualElement("cta_overrides", "ctaOverrides")),
            expiresAtMs = parseIsoMillis(map.dualString("expires_at", "expiresAt")),
        )
    }

    private fun ctaOverrideFromObject(map: JsonObject): CtaOverride? = guard("CtaOverride") {
        val id = map.dualString("cta_id", "ctaId")?.trim().orEmpty()
        if (id.isEmpty()) return@guard null
        val label = labelFrom(map["label"], legacyTitle = null).takeIf { it.isValid }
        CtaOverride(
            ctaId = id,
            label = label,
            goldCoins = map.dualInt("gold_coins", "goldCoins"),
            redCards = map.dualInt("red_cards", "redCards"),
        )
    }

    private fun postActionOutcomeFromObject(map: JsonObject): PostActionOutcome? =
        guard("PostActionOutcome") {
            val status = map.stringOrNull("status").orEmpty()
            if (status.isEmpty()) return@guard null
            PostActionOutcome(
                lifecycleActionType = map.dualString("lifecycle_action_type", "lifecycleActionType")
                    .orEmpty(),
                status = OutcomeStatus.fromRaw(status),
                label = labelFrom(
                    map["title_label"] ?: map["titleLabel"],
                    legacyTitle = map.stringOrNull("title"),
                ),
                subtitleLabel = labelFrom(
                    map["subtitle_label"] ?: map["subtitleLabel"],
                    legacyTitle = map.stringOrNull("subtitle"),
                ).takeIf { it.isValid },
                goldCoins = map.dualInt("gold_coins", "goldCoins") ?: 0,
                redCards = map.dualInt("red_cards", "redCards") ?: 0,
                goldCoinsTotal = map.dualInt("gold_coins_total", "goldCoinsTotal"),
                redCardsTotal = map.dualInt("red_cards_total", "redCardsTotal"),
                iconUrl = map.dualString("icon_url", "iconUrl")?.trim()?.takeIf { it.isNotEmpty() },
            )
        }

    private fun ctaOverrideList(raw: JsonElement?): List<CtaOverride>? {
        val array = raw as? JsonArray ?: return null
        val list = array.mapObjects { ctaOverrideFromObject(it) }
        return list.ifEmpty { null }
    }

    /** Last-wins per lowercase cta id across all nudges (Dart `resolveCtaOverridesFromNudges`). */
    private fun resolveCtaOverrides(nudges: List<PreActionNudge>): Map<String, CtaOverride> {
        val map = LinkedHashMap<String, CtaOverride>()
        for (nudge in nudges) {
            val overrides = nudge.ctaOverrides ?: continue
            for (override in overrides) {
                map[override.ctaId.lowercase()] = override
            }
        }
        return map
    }

    // ── NudgeLabel parsing (port of Dart `NudgeLabel.fromDynamic`) ─────────────

    private fun labelFrom(raw: JsonElement?, legacyTitle: String?): NudgeLabel {
        if (raw == null || raw is JsonNull) {
            return legacyTitle?.takeIf { it.isNotEmpty() }?.let { NudgeLabel.literal(it) }
                ?: NudgeLabel.EMPTY
        }
        if (raw is JsonPrimitive && raw.isString) {
            return NudgeLabel.literal(raw.content)
        }
        val obj = raw as? JsonObject ?: return NudgeLabel.EMPTY
        val key = obj.stringOrNull("key").orEmpty()
        return NudgeLabel(
            key = key,
            params = normalizeParams(obj["params"] as? JsonObject),
            defaultText = obj.stringOrNull("default_text") ?: obj.stringOrNull("defaultText"),
        )
    }

    /**
     * Stringify param values and duplicate `red_cards` / `gold_coins` /
     * `deadline_time` into camelCase so `{{redCards}}`-style templates resolve on
     * snake_case payloads — mirrors Dart `_normalizeParams`.
     */
    private fun normalizeParams(params: JsonObject?): Map<String, String> {
        if (params == null) return emptyMap()
        val out = LinkedHashMap<String, String>()
        for ((k, v) in params) {
            out[k] = (v as? JsonPrimitive)?.contentOrNull ?: v.toString()
        }
        DUAL_PARAM_KEYS.forEach { (snake, camel) ->
            if (out.containsKey(snake) && !out.containsKey(camel)) out[camel] = out.getValue(snake)
        }
        return out
    }

    // ── helpers ───────────────────────────────────────────────────────────────

    private fun isStale(expiresAtMs: Long?, nowMs: Long): Boolean =
        expiresAtMs != null && nowMs > expiresAtMs

    /**
     * Parse an ISO-8601 timestamp to absolute epoch-millis, accepting both zoned
     * (`…Z` / offset) and naive (`2026-06-29T21:39:00.472071`) forms — the latter
     * resolved against the device timezone, matching Dart `DateTime.tryParse` and
     * `LunchProjector.isoMillis`. Null on blank / garbage.
     */
    @OptIn(kotlin.time.ExperimentalTime::class)
    private fun parseIsoMillis(raw: String?): Long? {
        val value = raw?.takeIf { it.isNotBlank() } ?: return null
        return try {
            Instant.parse(value).toEpochMilliseconds()
        } catch (_: IllegalArgumentException) {
            try {
                LocalDateTime.parse(value)
                    .toInstant(TimeZone.currentSystemDefault())
                    .toEpochMilliseconds()
            } catch (_: IllegalArgumentException) {
                null
            }
        }
    }

    private inline fun <T> guard(tag: String, block: () -> T?): T? = try {
        block()
    } catch (e: Exception) {
        onError(e, tag)
        null
    }

    private companion object {
        val DUAL_PARAM_KEYS = listOf(
            "red_cards" to "redCards",
            "gold_coins" to "goldCoins",
            "deadline_time" to "deadlineTime",
        )
    }
}

// ── JsonObject / JsonArray extension helpers (local to the parser) ─────────────

/** String content of any non-null primitive (numbers/bools coerced, matching Dart `toString()`). */
private fun JsonElement.asStringOrNull(): String? =
    (this as? JsonPrimitive)?.takeIf { it !is JsonNull }?.contentOrNull

private fun JsonElement.asIntOrNull(): Int? {
    val primitive = this as? JsonPrimitive ?: return null
    if (primitive is JsonNull) return null
    val content = primitive.contentOrNull ?: return null
    // Accept numeric strings and floats (e.g. "3", 3, 3.0), matching Dart anyValueToInt.
    return content.toIntOrNull() ?: content.toDoubleOrNull()?.toInt()
}

private fun JsonObject.stringOrNull(key: String): String? =
    this[key]?.takeIf { it !is JsonNull }?.asStringOrNull()

private fun JsonObject.dualString(snake: String, camel: String): String? =
    stringOrNull(snake) ?: stringOrNull(camel)

private fun JsonObject.dualInt(snake: String, camel: String): Int? =
    this[snake]?.asIntOrNull() ?: this[camel]?.asIntOrNull()

private fun JsonObject.dualElement(snake: String, camel: String): JsonElement? =
    this[snake]?.takeIf { it !is JsonNull } ?: this[camel]?.takeIf { it !is JsonNull }

private fun JsonObject.dualArray(snake: String, camel: String): JsonArray? =
    (dualElement(snake, camel)) as? JsonArray

/** Map only the object elements of an array through [transform], dropping nulls. */
private inline fun <T> JsonArray.mapObjects(transform: (JsonObject) -> T?): List<T> {
    val out = ArrayList<T>(size)
    for (element in this) {
        val obj = element as? JsonObject ?: continue
        transform(obj)?.let { out.add(it) }
    }
    return out
}
