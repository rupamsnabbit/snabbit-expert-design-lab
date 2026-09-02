package com.snabbit.runner.shared.core.network.interceptors

import com.snabbit.runner.shared.core.CurrentTimeMs
import com.snabbit.runner.shared.core.network.NetworkTuningStore
import com.snabbit.runner.shared.core.network.UnauthorizedDispatcher
import kotlinx.atomicfu.atomic

/**
 * Coalesces 401 bursts (§3.6). When three concurrent requests all come
 * back 401, [UnauthorizedDispatcher.dispatch] fires **once** — not three
 * times — so Dart's `handle403()` (stop services, clear upload queue,
 * navigate to login) runs once and is idempotent for the burst window.
 *
 * Debounce window: Remote-Config-driven via
 * `expert_kmp_network_401_debounce_ms` (default 2 seconds). Read per response
 * rather than captured at construction, so widening it during a token-service
 * incident — the case where a 401 storm would otherwise mass-log-out runners —
 * takes effect without a release. Under concurrency, atomic compare-and-set
 * ensures exactly one caller wins the fire.
 *
 * [currentTimeMs] is injected so tests can step the clock; production
 * wires the platform clock (e.g. `System::currentTimeMillis`).
 */
class UnauthorizedResponseObserver(
    private val dispatcher: UnauthorizedDispatcher,
    private val currentTimeMs: CurrentTimeMs,
    /**
     * Required rather than defaulted: a private, never-refreshed store would pin this
     * observer to the shipped debounce forever, silently — see [buildKtorClient].
     */
    private val networkTuningStore: NetworkTuningStore,
) {
    private val lastFired = atomic(0L)

    fun notifyResponse(statusCode: Int) {
        if (statusCode != 401) return
        val now = currentTimeMs()
        val prev = lastFired.value
        if (now - prev < networkTuningStore.snapshot().unauthorizedDebounceMs) return
        if (lastFired.compareAndSet(prev, now)) {
            dispatcher.dispatch()
        }
    }
}
