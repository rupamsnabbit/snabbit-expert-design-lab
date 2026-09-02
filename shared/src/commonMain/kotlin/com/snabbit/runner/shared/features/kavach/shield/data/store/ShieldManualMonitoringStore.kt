package com.snabbit.runner.shared.features.kavach.shield.data.store

import com.snabbit.runner.shared.core.storage.EncryptedStore

/**
 * Persists the `jobId` for which the runner MANUALLY activated recording ("Activate Kavach"), so a
 * manual MONITORING+RECORDING session survives resume/restart within the SAME job
 * (shield-sos-lifecycle-contract §2/§5). Read by [com.snabbit.runner.shared.features.kavach.shield.domain.restore.ShieldLayerRestore]
 * to re-derive `enabled = present && (auto || activeJobId == jobId)`.
 *
 * Keyed by `jobId` (not a global boolean) so a manual activation for one job can't leak recording
 * into a different job. `EncryptedStore`-backed like `SosPushStore` (StoreManager has no generic slot).
 */
class ShieldManualMonitoringStore(private val store: EncryptedStore) {
    /** The jobId a manual recording was activated for, or null if none. */
    suspend fun activeJobId(): Int? = store.getString(KEY)?.toIntOrNull()

    /** Persist that recording was manually activated for [jobId]. */
    suspend fun setActiveJob(jobId: Int) = store.putString(KEY, jobId.toString())

    /** Clear the manual-activation flag (no active job / session ended). */
    suspend fun clear() = store.delete(KEY)

    private companion object {
        const val KEY = "shield_manual_monitoring_job"
    }
}
