package com.snabbit.runner.shared.features.kavach.sos

import com.snabbit.runner.shared.features.kavach.sos.data.store.SosPushStore
import org.koin.mp.KoinPlatform

/**
 * iOS twin of the Android `SosPushEntry`. The iOS host's push handler (Firebase/APNs) calls this on
 * a `safety_shield_sos` data message (action + sos_id); the pending action is persisted via
 * [SosPushStore] and drained + applied on next foreground by `SafetyForegroundReconciler`.
 *
 * `suspend`, matching the Android twin. The iOS analogue of `onMessageReceived` returning is
 * invoking `didReceiveRemoteNotification`'s completion handler — that also ends the execution
 * window, so a detached `CoroutineScope(Dispatchers.Default).launch` could be killed mid-write and
 * silently drop the pending SOS action. The host must await the persist instead.
 *
 * Swift call shape is the completion-handler form Kotlin/Native generates for a suspend function:
 * `SosPushEntry.shared.onSosPush(action:sosId:completionHandler:)` — invoke the OS completion
 * handler from inside that callback, not before.
 *
 * Uses `KoinPlatform` (GlobalContext isn't multiplatform-resolvable on iOS).
 */
object SosPushEntry {
    suspend fun onSosPush(action: String, sosId: Int) {
        val store = runCatching { KoinPlatform.getKoin() }.getOrNull()?.get<SosPushStore>() ?: return
        store.persist(action, sosId)
    }
}
