package com.snabbit.runner.shared.features.kavach.sos.data.gateway

import com.snabbit.runner.shared.core.AppDispatchers
import com.snabbit.runner.shared.core.runnerstate.RunnerStateStore
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement

/**
 * Backend-driven SOS UI visibility, from `current_state.widget_data.sos_visibility.visible`.
 *
 * The backend uses this to hide the SOS entry outside a runner's shift window (its `reason` values
 * are `PRE_LOGIN_WINDOW`, `ON_LEAVE`, `NO_SHIFT_TODAY`, `OUTSIDE_WINDOW`, …). Flutter honours it at
 * `partner_home.dart:2289-2293`; KMP had **zero** references, so the native SOS pills stayed visible
 * for the whole cohort regardless of what the backend said.
 *
 * Defaults to **visible** when the field is absent or unparseable — matching Flutter's stated
 * backward-compatibility behaviour. Only an explicit `visible: false` hides the button, so a parse
 * problem can never take away a safety affordance.
 *
 * Decodes its own slice off the raw `widget_data` (the documented [RunnerStateStore] convention), so
 * adding this needed no bridge or envelope change.
 */
class SosVisibilityGateway(
    runnerStateStore: RunnerStateStore,
    dispatchers: AppDispatchers,
) {
    private val scope = CoroutineScope(SupervisorJob() + dispatchers.default)
    private val json = Json { ignoreUnknownKeys = true; isLenient = true }

    val visible: StateFlow<Boolean> = runnerStateStore.state
        // Slice the raw sos_visibility element first + dedupe it, so the JSON decode only runs when that
        // element actually changes — not on every unrelated current_state push.
        .map { it?.widgetData?.get(KEY) }
        .distinctUntilChanged()
        .map { parse(it) }
        .stateIn(scope, SharingStarted.Eagerly, true)

    private fun parse(raw: JsonElement?): Boolean {
        if (raw == null) return true
        return runCatching { json.decodeFromJsonElement(SosVisibilitySlice.serializer(), raw).visible }
            .getOrNull() ?: true
    }

    private companion object {
        const val KEY = "sos_visibility"
    }
}

/** `visible` nullable so an absent/garbled value falls back to shown, never hidden. */
@Serializable
private data class SosVisibilitySlice(
    @SerialName("visible") val visible: Boolean? = null,
)
