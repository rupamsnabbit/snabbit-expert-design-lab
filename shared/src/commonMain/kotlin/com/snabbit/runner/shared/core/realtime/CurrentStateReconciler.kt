package com.snabbit.runner.shared.core.realtime

import com.snabbit.runner.shared.core.Logger
import com.snabbit.runner.shared.core.network.SnabbitHttpClient
import com.snabbit.runner.shared.core.network.SnabbitRequest
import com.snabbit.runner.shared.core.result.Result
import io.ktor.http.HttpMethod
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

/**
 * The production [CurrentStateFetcher] (LLD §6.4): `GET current_state` over
 * [SnabbitHttpClient], mapped into the snapshot envelope. The backend stamps
 * `state_seq` on the response and re-publishes the same widget+seq to MQTT,
 * so HTTP and MQTT share one version space.
 *
 * Note (LLD §6.7): the legacy lat/lng/battery query params are deliberately
 * NOT sent — request-context fields are moving to the IoT-driven /
 * client-computed paths.
 */
class CurrentStateReconciler(
    private val http: SnabbitHttpClient,
    private val logger: Logger,
) : CurrentStateFetcher {

    // current_state carries the widget FLAT at the top level (widget_name +
    // widget_data), plus the sibling render fields — NOT nested under a `widget`
    // object like the MQTT STATE_SNAPSHOT envelope. Parse the flat shape here and
    // re-nest into a `widget` below so toRunnerStateJson() (which reads
    // widget.widget_name / widget.widget_data) matches the MQTT path exactly.
    @Serializable
    private data class CurrentStateDto(
        @SerialName("state_seq") val stateSeq: Long? = null,
        val epoch: Long = 0,
        @SerialName("widget_name") val widgetName: String? = null,
        @SerialName("widget_data") val widgetData: JsonElement? = null,
        @SerialName("sheet_warnings") val sheetWarnings: JsonElement? = null,
        @SerialName("gold_coins_total") val goldCoinsTotal: JsonElement? = null,
        @SerialName("red_cards_total") val redCardsTotal: JsonElement? = null,
        @SerialName("pre_action_nudges") val preActionNudges: JsonElement? = null,
        @SerialName("show_lunch_selection") val showLunchSelection: JsonElement? = null,
        // tier_nudge is a TOP-LEVEL sibling of widget_data on current_state (NOT inside
        // widget_data). It MUST be decoded here or the HTTP reconcile/degraded path silently
        // drops it: the MQTT-message path captures tier_nudge via SnapshotEnvelope.parse, but
        // this HTTP fetcher has its OWN DTO, so without this field the tiering nudge is null for
        // the whole MQTT cohort whenever it's running on the reconcile/degraded poll.
        @SerialName("tier_nudge") val tierNudge: JsonElement? = null,
    )

    private val json = Json { ignoreUnknownKeys = true; isLenient = true }

    override suspend fun fetch(): SnapshotEnvelope? {
        val request = SnabbitRequest(
            method = HttpMethod.Get,
            url = "/$PATH",
            query = mapOf("is_fg" to "true"),
        )
        return when (val result = http.execute(request)) {
            is Result.Ok -> parse(result.value.body)
            is Result.Err -> {
                logger.w(TAG, "current_state fetch failed: ${result.error}")
                null
            }
        }
    }

    private fun parse(body: String): SnapshotEnvelope? = try {
        val dto = json.decodeFromString<CurrentStateDto>(body)
        // Ordering is by state_seq (SnapshotStore.isNewer). The backend now stamps
        // an epoch-based monotonic state_seq on current_state too, shared with the
        // MQTT path — so a missing state_seq is a backend regression: fall back to 0
        // (seed-only, first-wins), NOT a client clock, which would out-rank the
        // backend's real seqs and starve every later MQTT/FETCH update.
        val seq = dto.stateSeq ?: 0
        if (dto.stateSeq == null) {
            logger.w(TAG, "current_state carries no state_seq — applying as seq=0 (seed-only)")
        }
        // Re-nest the flat widget_name/widget_data into the envelope's `widget`
        // so toRunnerStateJson() matches the MQTT path. Null widget_name ⇒ null
        // widget (empty/idle state).
        val widget = dto.widgetName?.let { name ->
            buildJsonObject {
                put("widget_name", JsonPrimitive(name))
                dto.widgetData?.let { put("widget_data", it) }
            }
        }
        SnapshotEnvelope(
            epoch = dto.epoch,
            stateSeq = seq,
            widget = widget,
            sheetWarnings = dto.sheetWarnings,
            goldCoinsTotal = dto.goldCoinsTotal,
            redCardsTotal = dto.redCardsTotal,
            preActionNudges = dto.preActionNudges,
            showLunchSelection = dto.showLunchSelection,
            tierNudge = dto.tierNudge,
        )
    } catch (e: Exception) {
        logger.e(TAG, "current_state parse failed", e)
        null
    }

    private companion object {
        const val TAG = "CurrentStateReconciler"
        const val PATH = "api/v1/runners/me/app/current_state"
    }
}
