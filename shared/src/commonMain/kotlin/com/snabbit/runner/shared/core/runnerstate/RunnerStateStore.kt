package com.snabbit.runner.shared.core.runnerstate

import com.snabbit.runner.shared.core.Logger
import kotlinx.atomicfu.atomic
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject

/**
 * The runner's current `current_state` envelope, mirrored from the Flutter
 * `RunnerRtDataProvider`. Dart owns polling + orchestration; this is the read
 * model the KMP / Compose Multiplatform surfaces (Expert App 2.0) observe.
 *
 * [widgetData] is deliberately kept as a raw [JsonObject] — the bridge stays
 * agnostic to the long, fast-moving tail of per-widget fields (job_id, lat/lng,
 * awol, delayed_checkin_penalty, …). Each screen's ViewModel decodes only the
 * slice it needs (`Json.decodeFromJsonElement<…>(widgetData)`), so a new field
 * never requires a bridge change.
 */
@Serializable
data class RunnerState(
    @SerialName("widget_name") val widgetName: String? = null,
    @SerialName("widget_data") val widgetData: JsonObject? = null,
)

/**
 * Holds the latest [RunnerState] pushed from Dart and exposes it as a hot,
 * state-holding [StateFlow]. Single instance, owned by Koin (`coreModule`) —
 * the KMP analogue of `NetworkConfigStore`.
 *
 * Why a [MutableStateFlow] and not an event channel: it replays its current
 * value to every new collector, so a Compose screen mounting mid-shift sees the
 * live state immediately instead of waiting for the next Dart push. Equal
 * envelopes are coalesced by [MutableStateFlow], so a re-pushed unchanged state
 * never re-notifies collectors.
 *
 * Dart is the single source of truth — this store is write-from-Dart,
 * read-from-Compose. [pushState] never throws: a malformed payload is logged and
 * the last good state is preserved (stale-but-valid beats a blank UI).
 *
 * Reverse direction: [requestRefresh] asks Dart to re-fetch `current_state`
 * now (e.g. user pulled-to-refresh, screen mounted mid-shift). The host
 * (Android `RunnerStatePlugin`, future iOS equivalent) installs a [bind]
 * bridge on plugin attach that forwards the request over the existing
 * `com.snabbit.runner/runner_state` MethodChannel. Fire-and-forget — the
 * refreshed envelope flows back through [pushState] at the end of Dart's
 * `_fetchData()`, so observers see the result without a second bridge call.
 * No-op if the bridge isn't bound (plugin not yet attached / detached).
 */
class RunnerStateStore(private val logger: Logger) {

    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
    }

    private val _state = MutableStateFlow<RunnerState?>(null)
    private val _envelope = MutableStateFlow<JsonObject?>(null)
    private val refreshBridge = atomic<(() -> Unit)?>(null)
    private val postActionBridge = atomic<((String) -> Unit)?>(null)

    /** Latest pushed state, or null before the first push. Replays to new collectors. */
    val state: StateFlow<RunnerState?> = _state.asStateFlow()

    /**
     * The full raw `current_state` envelope as a [JsonObject], or null before the
     * first push. [RunnerState] intentionally decodes only `widget_name` /
     * `widget_data`, but some read models need **top-level siblings** that live
     * alongside those keys — e.g. gamification's `sheet_warnings`,
     * `gold_coins_total`, `red_cards_total`, and a top-level `pre_action_nudges`.
     * Exposing the raw object here keeps the store feature-agnostic (it names no
     * feature field) while letting a projector fold whichever siblings it needs,
     * exactly as VMs already decode slices out of [RunnerState.widgetData].
     */
    val envelope: StateFlow<JsonObject?> = _envelope.asStateFlow()

    /** Non-suspending peek — null if nothing has been pushed yet. */
    fun snapshot(): RunnerState? = _state.value

    /**
     * Decode [rawJson] (the `{ "widget_name", "widget_data", … }` envelope) and
     * publish both the typed [state] and the raw [envelope]. A decode failure is
     * logged at ERROR and leaves the previous values untouched (stale-but-valid
     * beats a blank UI). The two are published together so collectors of either
     * flow always observe a consistent pair.
     */
    fun pushState(rawJson: String) {
        try {
            val element = json.parseToJsonElement(rawJson)
            val envelopeObject = element as? JsonObject
            _state.value = json.decodeFromJsonElement(RunnerState.serializer(), element)
            _envelope.value = envelopeObject
        } catch (e: Exception) {
            logger.e(TAG, "pushState decode failed; keeping last good state", e)
        }
    }

    /**
     * Install (or clear, with `null`) the bridge that forwards [requestRefresh]
     * to Dart. Called by the host plugin on attach/detach.
     */
    fun bind(bridge: (() -> Unit)?) {
        refreshBridge.value = bridge
    }

    /** Ask Dart to re-fetch `current_state`. No-op if no bridge is bound. */
    fun requestRefresh() {
        refreshBridge.value?.invoke()
    }

    /**
     * Install (or clear, with `null`) the bridge that forwards [onPostAction] to
     * the realtime engine (feature #4). Distinct from [bind]: this one routes
     * straight to the KMP engine's post-action deadline (NOT through Dart), so it
     * stays a no-op for the polling cohort where no engine is running.
     */
    fun bindPostAction(bridge: ((String) -> Unit)?) {
        postActionBridge.value = bridge
    }

    /**
     * Signal that a state-mutating runner action ([action] = a short telemetry
     * label) just succeeded, so the engine arms its post-action fallback: if no
     * newer MQTT snapshot lands within the RC window, it fetches current_state
     * once. Fire-and-forget; no-op if no bridge is bound (polling cohort / iOS).
     */
    fun onPostAction(action: String) {
        postActionBridge.value?.invoke(action)
    }

    private companion object {
        const val TAG = "RunnerStateStore"
    }
}
