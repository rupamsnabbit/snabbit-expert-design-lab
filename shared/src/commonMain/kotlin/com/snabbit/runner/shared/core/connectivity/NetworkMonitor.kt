package com.snabbit.runner.shared.core.connectivity

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/**
 * Platform seam for observing device connectivity — the network analogue of
 * [com.snabbit.runner.shared.features.job.domain.JobClock]. `commonMain` stays pure: the contract
 * is a hot [StateFlow]; the Android / iOS implementations live in their platform source
 * sets and are bound in the platform Koin module.
 *
 * [status] is always-valued (seeded with a best-effort initial status) and conflated, so
 * a late collector immediately sees the current state. The polling→push swap seam lives
 * behind this interface: swap the implementation (e.g. for a latency-based probe) without
 * touching the UI.
 */
interface NetworkMonitor {
    val status: StateFlow<ConnectivityStatus>
}

/**
 * No-op monitor that always reports [ConnectivityStatus.Online]. Used as the
 * [com.snabbit.runner.shared.core.realtime.RealtimeStateEngine] seam default (and by
 * previews/spikes) so the connectivity-gated fallback degrades to "always poll" when
 * no real monitor is wired; production injects `AndroidNetworkMonitor` via Koin.
 */
object AlwaysOnlineNetworkMonitor : NetworkMonitor {
    override val status: StateFlow<ConnectivityStatus> =
        MutableStateFlow(ConnectivityStatus.Online)
}
