package com.snabbit.runner.shared.features.autoot.data

import com.snabbit.runner.shared.core.appconfig.AppConfigStore
import com.snabbit.runner.shared.core.remoteconfig.RemoteConfigGateway
import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.core.runnerstate.RunnerState
import com.snabbit.runner.shared.core.runnerstate.RunnerStateStore
import com.snabbit.runner.shared.features.autoot.data.remote.dto.AutoOtDto
import com.snabbit.runner.shared.features.autoot.domain.AutoOtTrigger
import com.snabbit.runner.shared.features.autoot.domain.model.AutoOtDetails
import com.snabbit.runner.shared.features.autoot.domain.model.OtType
import com.snabbit.runner.shared.features.autoot.domain.repository.AutoOtRepository
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.decodeFromJsonElement

/**
 * Read-side orchestrator for Auto-OT — the KMP analogue of Flutter
 * `AutoOtOrchestrator`. Observes the [RunnerStateStore] current-state stream,
 * decodes the `widget_data["auto_ot"]` slice, and publishes an [AutoOtTrigger]
 * the presentation layer turns into a mounted sheet. Also drives the pre-shift
 * (START_OT) probe via [onAttendanceMarked].
 *
 * END_OT offers ride the current-state stream; START_OT is fetched on demand and
 * injected into the same [trigger], so there is a single mount source.
 *
 * Mirrors the Flutter decisions:
 *  - a job / suspension widget preempts an active offer → [AutoOtTrigger.Preempt];
 *  - a new `auto_ot` (different request id) → [AutoOtTrigger.Offer] (deduped by id);
 *  - `auto_ot` disappearing clears an END_OT offer (Flutter `reset()`), but NOT a
 *    START_OT one (which never rode the stream — Flutter skips reset for `StartOt`).
 *
 * Decode never throws (a malformed slice is ignored), matching the Flutter
 * orchestrator's "orchestration must never break polling" contract.
 */
class AutoOtCoordinator(
    private val store: RunnerStateStore,
    private val repository: AutoOtRepository,
    private val appConfig: AppConfigStore,
    private val remoteConfig: RemoteConfigGateway,
    private val scope: CoroutineScope,
) {

    /**
     * Feature kill-switch — mirrors Flutter's `enableAutoOt` gate (RC `expert_enable_auto_ot`,
     * default false; `runner_rt_data.dart:1275`). When off, the coordinator emits no offers and
     * runs no START_OT probe, so KMP Auto OT is fully inert. Mirrored into KMP via
     * `KmpRemoteConfigMirror`; the safe default keeps OT off until the flag syncs.
     */
    private fun isEnabled(): Boolean = remoteConfig.getBool(RC_ENABLE_AUTO_OT, default = false)
    private val json = Json { ignoreUnknownKeys = true; isLenient = true }

    private val _trigger = MutableStateFlow<AutoOtTrigger>(AutoOtTrigger.None)
    val trigger: StateFlow<AutoOtTrigger> = _trigger.asStateFlow()

    /** Request id currently surfaced (dedupe); null when none is active. */
    private var activeRequestId: Int? = null

    /** OtType of the active offer — START_OT offers are not on the stream, so keep them. */
    private var activeOtType: OtType? = null

    init {
        scope.launch { store.state.collect { evaluate(it) } }
    }

    /** Pre-shift probe after attendance is marked (Flutter `onAttendanceMarked`). Best-effort. */
    fun onAttendanceMarked() {
        if (!isEnabled()) return
        scope.launch {
            when (val r = repository.requestStartOt()) {
                is Result.Ok -> r.value?.let(::emitOffer)
                is Result.Err -> Unit // no offer surfaced
            }
        }
    }

    /**
     * Server cancellation (`AUTO_OT_CANCELLED` push, bridged from Dart) — flip an active offer to
     * expired. Mirrors Flutter `handleAutoOtCancellation` (`if (isActive && !isExpired) …`);
     * no-op when nothing is active.
     */
    fun onCancelled() {
        // Hop onto the (single-thread-confined) scope: `activeRequestId` is also written by the
        // stream collector / onAttendanceMarked, so reading it off the caller's thread (Flutter
        // main) would be an unsynchronized cross-thread access.
        scope.launch { if (activeRequestId != null) _trigger.value = AutoOtTrigger.Cancelled }
    }

    /**
     * The VM finished with the current offer (terminal step reached or sheet dismissed) → reset the
     * one-shot trigger so a later collector (e.g. a recreated shell VM, while this singleton
     * survives) doesn't replay a consumed offer. Keeps [activeRequestId] so the stream's dedupe
     * still suppresses the same offer; an END_OT offer leaving the stream clears the id via
     * [evaluate]. START_OT never rides the stream, so this is its only reset path.
     */
    fun onOfferConsumed() {
        _trigger.value = AutoOtTrigger.None
    }

    /**
     * Signal a completed Auto-OT action so the runner-state read model refreshes — WS5 realtime
     * "feature #4": arms the engine's TIMED, seq-gated post-action fallback (if no newer MQTT
     * snapshot lands within `expert_mqtt_post_action_timeout_seconds`, it fetches current_state
     * once). Mirrors every other action site (job / check-in / checkout / attendance / lunch); a
     * no-op for the polling cohort (no engine bound), where the next poll tick carries the update.
     * Replaces the old eager `store.requestRefresh()` — see `RealtimeStateEngine.onPostAction`.
     */
    fun onPostAction(action: String) = store.onPostAction(action)

    /**
     * Widgets that suppress an OT offer — the backend's `app_config.blocked_auto_ot_widgets`
     * (mirrored into [AppConfigStore]) when present, else the baked [BLOCKED_WIDGETS] fallback.
     * Mirrors Flutter `blockedWidgets => appConfig?.blockedAutoOTWidgets ?? [default]`
     * (`auto_ot_provider.dart:74`), so KMP stays in sync when the backend changes the list.
     */
    private fun blockedWidgets(): Set<String> =
        (appConfig.snapshot()?.get("blocked_auto_ot_widgets") as? JsonArray)
            ?.mapNotNull { (it as? JsonPrimitive)?.contentOrNull }
            ?.toSet()
            ?.takeIf { it.isNotEmpty() }
            ?: BLOCKED_WIDGETS

    private fun evaluate(envelope: RunnerState?) {
        if (!isEnabled()) return // feature kill-switch (Flutter `if (enableAutoOt)`)
        val widgetName = envelope?.widgetName
        if (widgetName != null && widgetName in blockedWidgets()) {
            if (activeRequestId != null) {
                clearActive()
                _trigger.value = AutoOtTrigger.Preempt
            }
            return
        }

        val autoOtObject = envelope?.widgetData?.get("auto_ot") as? JsonObject
        if (autoOtObject != null) {
            val details = runCatching { json.decodeFromJsonElement<AutoOtDto>(autoOtObject).toDomain() }.getOrNull()
            if (details != null) emitOffer(details)
            // parse failure / incomplete offer → ignore (never crash the collector)
        } else if (activeRequestId != null && activeOtType != OtType.StartOt) {
            clearActive()
            _trigger.value = AutoOtTrigger.None
        }
    }

    private fun emitOffer(details: AutoOtDetails) {
        if (!details.isComplete) return // Flutter shows only when id + both shifts are present
        if (details.requestId == activeRequestId) return // dedupe by request id
        activeRequestId = details.requestId
        activeOtType = details.otType
        _trigger.value = AutoOtTrigger.Offer(details)
    }

    private fun clearActive() {
        activeRequestId = null
        activeOtType = null
    }

    private companion object {
        /** RC kill-switch key — must match Flutter `RemoteConfigKeys.enableAutoOt` + the mirror. */
        const val RC_ENABLE_AUTO_OT = "expert_enable_auto_ot"

        /**
         * Fallback block-list used only when `app_config.blocked_auto_ot_widgets` hasn't been
         * pushed yet — mirrors Flutter's `?? [default]` in `auto_ot_provider.dart:74`. The live
         * value comes from [blockedWidgets] (backend can shrink/grow it; prod currently sends
         * CHECK_IN / NEW_JOB / SUSPENDED only).
         */
        val BLOCKED_WIDGETS = setOf(
            "RUNNER_JOB_IN_PROGRESS",
            "RUNNER_JOB_POST_ACCEPT",
            "RUNNER_JOB_CHECK_IN",
            "RUNNER_NEW_JOB",
            "RUNNER_SUSPENDED",
        )
    }
}
