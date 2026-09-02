package com.snabbit.runner.shared.features.job.delayedcheckin.data

import com.snabbit.runner.shared.core.Logger
import com.snabbit.runner.shared.features.job.data.asIntOrNull
import com.snabbit.runner.shared.features.job.data.asStringOrNull
import com.snabbit.runner.shared.features.job.data.obj
import com.snabbit.runner.shared.features.job.delayedcheckin.domain.model.AwaitingCheckin
import com.snabbit.runner.shared.features.job.delayedcheckin.domain.model.PenaltyNudge
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.contentOrNull
import kotlin.time.Instant

private const val TAG = "PenaltyJsonReaders"
private const val DEFAULT_TOTAL_SECONDS = 300
private const val DEFAULT_RECEIVED_RED_CARDS = 0

/**
 * Parses `countdown.trigger_at` on the `delayed_checkin_penalty` widget
 * payload — an epoch-milliseconds number OR an ISO-8601 string. Never
 * throws: null, junk, or an unparseable value all resolve to `null`.
 *
 * Behavioural parity source (Dart, read-only): `parseDateTime` in
 * `lib/utils/common_methods.dart` (`DateTime.fromMillisecondsSinceEpoch` for
 * a `num`, `DateTime.tryParse` for a `String`).
 *
 * Timezone contract (deliberate): the string path requires an explicit UTC
 * offset (`Z`/`±hh:mm`) — the shape maestro-core emits (Python `isoformat()`
 * on a tz-aware datetime; all fixtures carry `+05:30`/`Z`) and the epoch-ms
 * path is unambiguous. An offset-*less* string (`2026-07-11T14:30:00`)
 * resolves to `null` and drops the penalty view rather than guessing a
 * timezone: Dart's `DateTime.tryParse` would read it as device-local, but if
 * the backend ever meant UTC that guess is hours wrong. A fail-safe drop
 * beats a wrong countdown; revisit only if the backend starts sending naive
 * timestamps (add `kotlinx-datetime` + a device-local interpretation then).
 */
fun parseTriggerAt(el: JsonElement?): Instant? {
    val primitive = el as? JsonPrimitive ?: return null
    primitive.longOrNullCompat()?.let { epochMs ->
        return runCatching { Instant.fromEpochMilliseconds(epochMs) }.getOrNull()
    }
    val content = primitive.contentOrNull ?: return null
    return Instant.parseOrNull(content)
}

/**
 * A [JsonPrimitive] is a number-or-null the same way whether it arrived
 * quoted or unquoted on the wire — mirrors Dart `parseDateTime`'s `is num`
 * branch, which accepts ANY numeric shape via `.toInt()`. The double
 * fallback covers a float epoch (`1700000000000.0`, e.g. a backend JSON
 * encoder widening integers) that `toLongOrNull` alone rejects — without
 * it the whole penalty payload would be dropped. Still strictly numeric:
 * the fallback only fires when the entire content parses as a number, so
 * ISO-8601 strings continue to the string path.
 */
private fun JsonPrimitive.longOrNullCompat(): Long? =
    content.toLongOrNull() ?: content.toDoubleOrNull()?.toLong()

/**
 * Decodes the whole `widget_data.delayed_checkin_penalty` object into an
 * [AwaitingCheckin], applying the fixed defaulting table (LLD):
 *
 *  - [json] itself absent (whole key missing on `widget_data`) -> `null`.
 *  - `countdown.trigger_at` missing/unparseable -> `null` + a logged
 *    warning (a timer-less penalty view is undefined — there is nothing
 *    sane to render).
 *  - `countdown.total_seconds` missing/malformed -> `300`.
 *  - `received_red_cards` missing/malformed -> `0`.
 *  - `card_value` absent -> `null`.
 *
 * The deduction nudge is NOT read here: the real backend sends it as the
 * sibling `widget_data.pre_action_nudges` array (see [decodePreActionNudge]),
 * never inside the penalty slice. Tolerant field reads reuse the shared
 * `job.data` JsonReaders — one place owns the string/number tolerance rules.
 */
fun decodeAwaitingCheckin(json: JsonObject?, logger: Logger? = null): AwaitingCheckin? {
    if (json == null) return null

    val countdown = json.obj("countdown")
    val deadline = parseTriggerAt(countdown?.get("trigger_at"))
    if (deadline == null) {
        logger?.w(TAG, "decodeAwaitingCheckin: trigger_at missing/unparseable; dropping penalty view")
        return null
    }

    return AwaitingCheckin(
        deadline = deadline,
        totalSeconds = countdown?.get("total_seconds").asIntOrNull() ?: DEFAULT_TOTAL_SECONDS,
        receivedRedCards = json["received_red_cards"].asIntOrNull() ?: DEFAULT_RECEIVED_RED_CARDS,
        cardValue = json["card_value"].asIntOrNull(),
    )
}

private const val DC_LIFECYCLE_ACTION_TYPE = "DELAYED_CHECKIN_PENALTY"

/**
 * Decodes the delayed check-in entry of `widget_data.pre_action_nudges` —
 * the shape the REAL backend sends (`attach_delayed_checkin_to_widget`,
 * maestro-core `src/runner/service.py`): the nudge rides as a SIBLING of
 * `delayed_checkin_penalty`, not inside it, with a structured label
 * (`{key, default_text, params}`). `default_text` arrives pre-formatted by
 * the backend ("1 red card will be added"), so no client-side param
 * interpolation is needed. Selection is by `lifecycle_action_type` — other
 * nudge kinds (gamification coins etc.) are ignored.
 *
 * Never throws: a missing/malformed array, entry, or label resolves to
 * `null`, same contract as [decodeAwaitingCheckin].
 */
fun decodePreActionNudge(widgetData: JsonObject?): PenaltyNudge? {
    // The Dart parity source (GamificationManager.parseNudges) accepts both the
    // snake_case `pre_action_nudges` and camelCase `preActionNudges` keys (some
    // backend serializers emit camelCase). Tolerate both here — snake_case primary,
    // camelCase as fallback — or the KMP banner silently no-shows where Flutter renders it.
    val nudges = (widgetData?.get("pre_action_nudges") ?: widgetData?.get("preActionNudges"))
        as? JsonArray ?: return null
    val entry = nudges.filterIsInstance<JsonObject>().firstOrNull {
        val type = it["lifecycle_action_type"].asStringOrNull()
            ?: it["lifecycleActionType"].asStringOrNull()
        type == DC_LIFECYCLE_ACTION_TYPE
    } ?: return null
    val label = entry.obj("label")?.get("default_text").asStringOrNull()
        ?.takeIf { it.isNotBlank() }
        ?: entry["label"].asStringOrNull()?.takeIf { it.isNotBlank() } // tolerate a flat string label
        ?: return null
    return PenaltyNudge(
        label = label,
        redCards = entry["red_cards"].asIntOrNull(),
        iconUrl = entry["icon_url"].asStringOrNull(),
    )
}
