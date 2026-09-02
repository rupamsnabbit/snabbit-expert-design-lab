package com.snabbit.runner.shared.features.kavach.sos.data.store

import com.snabbit.runner.shared.core.storage.EncryptedStore

/**
 * Persists "this runner has an SOS the backend may still consider open", so §16 recovery can run
 * after a process death — [com.snabbit.runner.shared.features.kavach.sos.domain.SosCoordinator]'s
 * phase lives in memory only and dies with the process.
 *
 * This is the reason gate for the foreground reconcile: without it (and without a pending FCM push)
 * there is nothing to recover, so the app must NOT call `/sos/active` on launch.
 *
 * Lifecycle — set on raise, cleared on resolve, AND cleared whenever a reconcile confirms the
 * backend has no active SOS. That third clear is what stops a flag orphaned by a crash-between-
 * resolve-and-clear from making every future launch reconcile forever.
 *
 * `EncryptedStore`-backed, matching [SosPushStore] and `ShieldManualMonitoringStore`.
 */
class SosLiveStore(private val store: EncryptedStore) {
    /** True while an SOS may still be open backend-side. */
    suspend fun isLive(): Boolean = store.getString(KEY) == VALUE_LIVE

    /** Mark an SOS as raised — survives process death so the next foreground can reconcile it. */
    suspend fun markLive() = store.putString(KEY, VALUE_LIVE)

    /** Resolved (confirmed/denied/de-escalated) or reconciled away — nothing left to recover. */
    suspend fun clear() = store.delete(KEY)

    private companion object {
        const val KEY = "shield_sos_live"
        const val VALUE_LIVE = "1"
    }
}
