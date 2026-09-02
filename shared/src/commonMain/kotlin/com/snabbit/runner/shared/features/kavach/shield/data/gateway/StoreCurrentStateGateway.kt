package com.snabbit.runner.shared.features.kavach.shield.data.gateway

import com.snabbit.runner.shared.core.runnerstate.RunnerState
import com.snabbit.runner.shared.core.runnerstate.RunnerStateStore
import com.snabbit.runner.shared.features.kavach.shield.data.remote.ShieldWidgetSlice
import com.snabbit.runner.shared.features.kavach.shield.data.remote.jobIdAsInt
import kotlinx.serialization.json.Json

/**
 * Prod [CurrentStateGateway] backed by the in-memory [RunnerStateStore] — the same `current_state`
 * envelope the app already keeps live (Dart poll + realtime + FCM). Resolves the deferred "Decision A"
 * to the store-read path: no HTTP re-fetch, so kavach's job/consent gates reuse data already on device.
 *
 * A null store snapshot means nothing has been pushed yet (cold) → surfaced as a null gateway snapshot
 * (fail-closed), matching the old HTTP impl's fetch-failure contract so [com.snabbit.runner.shared.features.kavach.shield.domain.restore.ShieldLayerRestore]
 * never under-arms on a blip (#R6).
 *
 * Reads only — it must not write `JobIdCache`: `job_id` here lags the in-progress envelope, which
 * attributed clips to the previous job (ECPO-986). The arm sites latch it instead.
 */
class StoreCurrentStateGateway(
    private val runnerStateStore: RunnerStateStore,
) : CurrentStateGateway {

    private val json = Json { ignoreUnknownKeys = true; isLenient = true }

    // Peek the live envelope. null = nothing pushed yet (cold) → treat as unavailable.
    private fun read(): Pair<RunnerState, ShieldWidgetSlice?>? {
        val state = runnerStateStore.snapshot() ?: return null
        val slice = state.widgetData?.let {
            runCatching { json.decodeFromJsonElement(ShieldWidgetSlice.serializer(), it) }.getOrNull()
        }
        return state to slice
    }

    override suspend fun currentJobId(): Int? = read()?.second?.jobIdAsInt()
    override suspend fun customerConsentEnabled(): Boolean = read()?.second?.customerConsentEnabled ?: false
    override suspend fun autoEnabled(): Boolean = read()?.second?.autoEnabled ?: false
    override suspend fun widgetName(): String? = read()?.first?.widgetName

    // One read → all fields. null ONLY on a cold store (unavailable); a pushed envelope with no shield
    // job is a non-null snapshot with jobId == null (genuine no-job), so restore doesn't clear on a blip.
    override suspend fun snapshot(): CurrentStateSnapshot? {
        val (state, slice) = read() ?: return null
        return CurrentStateSnapshot(
            jobId = slice?.jobIdAsInt(),
            customerConsentEnabled = slice?.customerConsentEnabled ?: false,
            autoEnabled = slice?.autoEnabled ?: false,
            widgetName = state.widgetName,
        )
    }
}
