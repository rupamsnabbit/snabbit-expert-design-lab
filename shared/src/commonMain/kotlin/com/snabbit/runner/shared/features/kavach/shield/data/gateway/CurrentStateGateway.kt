package com.snabbit.runner.shared.features.kavach.shield.data.gateway

/**
 * Active-job context for the shield enablement gate, sourced from `current_state.widget_data`
 * (job_id + the two customer-facing shield flags). A seam like [RemoteConfigGateway]: the
 * commonMain [DefaultCurrentStateGateway] is the safe no-host fallback; the real source
 * (HTTP re-fetch vs Flutter-owned state) is a pending decision, wired in `:app`.
 */
interface CurrentStateGateway {
    suspend fun currentJobId(): Int?
    suspend fun customerConsentEnabled(): Boolean
    suspend fun autoEnabled(): Boolean
    suspend fun widgetName(): String?

    /**
     * Atomic snapshot of the current-state fields in one fetch. Returns null ONLY on a fetch/parse
     * FAILURE — callers that mutate persisted state on the result (e.g. [ShieldLayerRestore]) must
     * distinguish that from a genuine no-job (a non-null snapshot with `jobId == null`), so a
     * transient blip can't wipe manual-monitoring state or silently downgrade.
     */
    suspend fun snapshot(): CurrentStateSnapshot?
}

/** One consistent read of `current_state.widget_data`; `jobId == null` here means a genuine no-job. */
data class CurrentStateSnapshot(
    val jobId: Int?,
    val customerConsentEnabled: Boolean,
    val autoEnabled: Boolean,
    val widgetName: String?,
)

/** No host context → no job, nothing enabled (→ ACCELEROMETER_ONLY floor). */
class DefaultCurrentStateGateway : CurrentStateGateway {
    override suspend fun currentJobId(): Int? = null
    override suspend fun customerConsentEnabled(): Boolean = false
    override suspend fun autoEnabled(): Boolean = false
    override suspend fun widgetName(): String? = null

    // No host is a genuine no-job (not a failure) → non-null snapshot with jobId = null.
    override suspend fun snapshot(): CurrentStateSnapshot? = CurrentStateSnapshot(null, false, false, null)
}
