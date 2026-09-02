package com.snabbit.runner.shared.core.connectivity

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * iOS [NetworkMonitor] — placeholder. The app currently ships Android-only (no iOS Koin
 * bootstrap binds this), so this reports a constant [ConnectivityStatus.Online] (the safe
 * default → no banner) rather than shipping unverifiable `NWPathMonitor` cinterop that this
 * environment can't compile.
 *
 * When iOS ships, replace the body with an `NWPathMonitor`-backed flow behind this same
 * [NetworkMonitor] contract (`.unsatisfied` → Offline; `.satisfied && isConstrained` →
 * BadConnection; else Online) and bind it in the iOS platform Koin module.
 */
class IosNetworkMonitor : NetworkMonitor {
    override val status: StateFlow<ConnectivityStatus> =
        MutableStateFlow(ConnectivityStatus.Online).asStateFlow()
}
