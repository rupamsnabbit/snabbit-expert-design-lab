package com.snabbit.runner.shared.features.kavach.shield.domain.upload

import com.snabbit.runner.shared.core.AppDispatchers
import com.snabbit.runner.shared.core.connectivity.Connectivity
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.drop
import kotlinx.coroutines.flow.filter
import kotlinx.coroutines.launch

/**
 * Drains the upload outbox on each offline→online edge. `drop(1)` skips the initial StateFlow value
 * (the coordinator already flushes the backlog once at launch), so this only fires on genuine
 * reconnects. [drain] = `ShieldUploadQueue.processQueue`, which is single-flight/idempotent, so
 * redundant calls are safe. Eager Koin single.
 */
class ShieldUploadReconnectTrigger(
    connectivity: Connectivity,
    private val drain: suspend () -> Unit,
    dispatchers: AppDispatchers,
) {
    private val scope = CoroutineScope(SupervisorJob() + dispatchers.default)

    init {
        scope.launch {
            connectivity.online.drop(1).filter { it }.collect {
                // A transient drain failure (e.g. a SQLite hiccup) must not complete this flow
                // exceptionally and kill the collector — later online edges still need to drain (#7).
                try {
                    drain()
                } catch (e: CancellationException) {
                    throw e
                } catch (e: Throwable) {
                    // swallow — retried on the next reconnect edge / the coordinator's launch flush
                }
            }
        }
    }
}
