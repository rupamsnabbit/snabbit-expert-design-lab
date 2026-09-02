package com.snabbit.runner.shared.core.realtime

import com.snabbit.runner.shared.core.Logger
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

/**
 * The retained state snapshot published on `maestro/user/{id}/state`
 * (LLD Appendix B). Unknown fields are ignored (forward-compat); missing
 * `epoch` defaults to 0 until the backend ships the epoch prefix (LLD §6.3);
 * missing `schema_version` defaults to 1.
 */
@Serializable
data class SnapshotEnvelope(
    @SerialName("event_type") val eventType: String = EVENT_STATE_SNAPSHOT,
    @SerialName("schema_version") val schemaVersion: Int = 1,
    val epoch: Long = 0,
    @SerialName("state_seq") val stateSeq: Long,
    /** The full server-driven widget: `{ "widget_name": …, "widget_data": { … } }` — mirrors `current_state`'s widget shape. */
    val widget: JsonObject? = null,
    // Top-level siblings of `widget` (same shape as `current_state`'s envelope) that the
    // Dart render reads directly — forwarded so an MQTT-driven state renders with full parity.
    @SerialName("sheet_warnings") val sheetWarnings: JsonElement? = null,
    @SerialName("gold_coins_total") val goldCoinsTotal: JsonElement? = null,
    @SerialName("red_cards_total") val redCardsTotal: JsonElement? = null,
    @SerialName("pre_action_nudges") val preActionNudges: JsonElement? = null,
    /** Lunch-slots banner flag — `current_state`'s top-level `show_lunch_selection`, forwarded
     *  for Dart's `RunnerRtDataProvider.showLunchSelection` fold (the banner is Flutter-side). */
    @SerialName("show_lunch_selection") val showLunchSelection: JsonElement? = null,
    // Top-level tiering nudge sibling (Expert Tiering) — carried through so the MQTT
    // cohort matches `current_state`; without this field the reconstruction below drops
    // it and TieringDataSource sees no nudge (the polling cohort forwards it via Dart).
    @SerialName("tier_nudge") val tierNudge: JsonElement? = null,
    val ts: Long? = null,
) {
    /**
     * Re-encodes into the `current_state`-shaped envelope that
     * [com.snabbit.runner.shared.core.runnerstate.RunnerStateStore.pushState]
     * consumes: `widget_name` + `widget_data` (lifted out of `widget`) plus the
     * top-level `sheet_warnings` / `gold_coins_total` / `red_cards_total` /
     * `pre_action_nudges` / `tier_nudge` and `state_seq` that Dart's `_fetchData`-parity
     * render reads. The engine feeds the existing store contract unchanged (LLD §5.1).
     *
     * NOTE: this is a WHITELIST — any new top-level `current_state` sibling the backend
     * adds must be added here (and as a field above) or the MQTT cohort silently drops it.
     */
    fun toRunnerStateJson(): String = buildJsonObject {
        put("widget_name", widget?.get("widget_name") ?: JsonNull)
        put("widget_data", widget?.get("widget_data") ?: JsonNull)
        put("sheet_warnings", sheetWarnings ?: JsonNull)
        put("gold_coins_total", goldCoinsTotal ?: JsonNull)
        put("red_cards_total", redCardsTotal ?: JsonNull)
        put("pre_action_nudges", preActionNudges ?: JsonNull)
        // The MQTT STATE_SNAPSHOT carries the FULL widget dump under `widget`
        // (backend `jsonable_encoder(widget)` — top-level siblings included), so
        // fall back to the widget-object field when the envelope doesn't lift it.
        put("show_lunch_selection", showLunchSelection ?: widget?.get("show_lunch_selection") ?: JsonNull)
        put("tier_nudge", tierNudge ?: JsonNull)
        put("state_seq", stateSeq)
    }.toString()

    companion object {
        const val EVENT_STATE_SNAPSHOT = "STATE_SNAPSHOT"

        /** Highest envelope schema this client understands (LLD App B guard). */
        const val SUPPORTED_SCHEMA_VERSION = 1

        private val json = Json {
            ignoreUnknownKeys = true
            isLenient = true
        }

        /** Lenient parse; malformed payloads return null (discard, never crash — LLD App A). */
        fun parse(raw: String, logger: Logger): SnapshotEnvelope? = try {
            json.decodeFromString<SnapshotEnvelope>(raw)
        } catch (e: Exception) {
            logger.e(TAG, "malformed snapshot payload discarded", e)
            null
        }

        private const val TAG = "SnapshotEnvelope"
    }
}
