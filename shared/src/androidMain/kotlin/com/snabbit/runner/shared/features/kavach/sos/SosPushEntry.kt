package com.snabbit.runner.shared.features.kavach.sos

import com.snabbit.runner.shared.features.kavach.sos.data.store.SosPushStore
import org.koin.core.context.GlobalContext

/**
 * Host FCM entry — the app's push service calls this on a `safety_shield_sos` data message
 * (action + sos_id). Persists the pending action via [SosPushStore]; it is drained and applied on
 * next foreground by `SafetyForegroundReconciler`. The FCM receipt/parse stays host-owned — this is
 * the fed seam between the host and the shared module.
 *
 * `suspend` (not fire-and-forget): the host awaits the encrypted persist within its FCM window, or
 * hands it to WorkManager. A bare-scope launch would drop the pending SOS action if the process is
 * killed right after `onMessageReceived` returns — a safety-critical loss on a killed-state push.
 */
object SosPushEntry {
    suspend fun onSosPush(action: String, sosId: Int) {
        val store = GlobalContext.getOrNull()?.get<SosPushStore>() ?: return
        store.persist(action, sosId)
    }
}
