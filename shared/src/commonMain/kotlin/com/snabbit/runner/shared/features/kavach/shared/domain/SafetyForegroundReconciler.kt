package com.snabbit.runner.shared.features.kavach.shared.domain
import com.snabbit.runner.shared.features.kavach.shield.domain.restore.ShieldLayerRestore
import com.snabbit.runner.shared.features.kavach.sos.domain.SosCoordinator

import com.snabbit.runner.shared.core.AppDispatchers
import com.snabbit.runner.shared.core.CrashReporter
import com.snabbit.runner.shared.core.lifecycle.AppLifecycle
import com.snabbit.runner.shared.features.kavach.sos.data.store.SosPushStore
import com.snabbit.runner.shared.features.kavach.sos.data.store.SosLiveStore
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.filter
import kotlinx.coroutines.launch

/**
 * §16 killed/backgrounded-state recovery. On each app foreground: (1) drain any pending FCM SOS
 * push, (2) reconcile with the backend (E3 `/sos/active`) so the phase is synced, (3) apply the
 * drained push against the reconciled phase. Order matters — reconcile before applyPush so the
 * phase-guarded confirm/deny act correctly (parity Flutter). Best-effort. Eager Koin single;
 * the [AppLifecycle] foreground StateFlow replays its current value so launch-into-foreground runs once.
 */
class SafetyForegroundReconciler(
    private val lifecycle: AppLifecycle,
    private val sosCoordinator: SosCoordinator,
    private val pushStore: SosPushStore,
    private val sosLiveStore: SosLiveStore,
    private val layerRestore: ShieldLayerRestore,
    private val crashReporter: CrashReporter,
    dispatchers: AppDispatchers,
) {
    private val scope = CoroutineScope(SupervisorJob() + dispatchers.default)

    init {
        scope.launch {
            lifecycle.foreground.filter { it }.collect {
                // Guard each foreground pass: restore()/reconcile() hit native + store I/O that can
                // throw; an unguarded throw completes the flow → §16 recovery is dead for the session.
                // Retried on the next foreground edge (#R-B).
                try {
                    val pending = pushStore.peek()
                    // Only reconcile when there is something to reconcile. `/sos/active` is runner-
                    // scoped and rare-by-nature, so firing it on every foreground (including a
                    // logged-out cold launch) only produced 401s — which trip the global unauthorized
                    // observer and force-log-out. Reasons to call: a pending FCM SOS action, or a
                    // persisted marker that this process left an SOS behind.
                    //
                    // Deliberately NOT gated on job or Kavach-enablement: a manual SOS is valid with
                    // no job, so either gate would strand exactly the session worth recovering.
                    if (pending != null || sosLiveStore.isLive()) {
                        sosCoordinator.reconcile()
                    }
                    if (pending != null) {
                        sosCoordinator.applyPush(pending.action, pending.sosId)
                        // Ack conditionally: delete only if THIS push is still current, so a newer push
                        // that arrived between peek() and here isn't dropped unapplied.
                        pushStore.clear(pending)
                    }
                    layerRestore.restore()   // §16: re-establish the expected layer (guards off during SOS)
                } catch (e: CancellationException) {
                    throw e
                } catch (e: Throwable) {
                    // best-effort for the collector's survival, but report — a persistent reconcile/restore
                    // failure means §16 recovery is broken for the session and was otherwise invisible.
                    crashReporter.report(e, mapOf("op" to "foregroundReconcile"))
                }
            }
        }
    }
}
