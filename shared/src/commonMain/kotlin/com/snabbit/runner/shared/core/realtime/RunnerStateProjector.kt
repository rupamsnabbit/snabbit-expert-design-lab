package com.snabbit.runner.shared.core.realtime

import com.snabbit.runner.shared.core.runnerstate.RunnerStateStore
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch

/**
 * DB-as-source-of-truth projection: collects [SnapshotStore.observe] and pushes
 * each version-gated snapshot into [RunnerStateStore] — the read model every KMP
 * / Compose Multiplatform surface observes. This replaces the old writer
 * inversion (engine → [SnapshotSink] → store): the store's persisted, seq-gated
 * row is now the ONLY thing that drives the UI, so there is exactly one write
 * path instead of the engine and Dart's bridge racing to push in parallel.
 *
 * Because [SnapshotStore.observe] replays the persisted row on subscription,
 * launching this IS the cold-boot seed (LLD §7): the last good snapshot paints
 * before the socket even connects, with no separate seed step (it retires the
 * one-shot "re-emit on Connected" hack the WS0 host carried).
 */
class RunnerStateProjector(
    private val store: SnapshotStore,
    private val target: RunnerStateStore,
) {
    /**
     * Start projecting on [scope]; the returned [Job] ends when [scope] is
     * cancelled (the service scope owns the lifecycle). Blank payloads are
     * skipped — [RunnerStateStore.pushState] keeps the last good state on a
     * decode miss, and re-pushed identical envelopes are coalesced by the
     * store's [kotlinx.coroutines.flow.MutableStateFlow].
     */
    fun start(scope: CoroutineScope): Job = scope.launch {
        store.observe().collect { applied ->
            applied?.widgetJson?.takeIf { it.isNotBlank() }?.let(target::pushState)
        }
    }
}
