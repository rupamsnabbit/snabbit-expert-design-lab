package com.snabbit.runner.shared.core.connectivity

/**
 * Device network reachability + quality, as surfaced to the UI (e.g. the connectivity
 * strip baked into [com.snabbit.runner.shared.ui.components.SnabbitActionFooter]).
 *
 * A read-model: produced by a [NetworkMonitor] and consumed through
 * [LocalConnectivityStatus]. [Online] is the safe default (no banner) so anything that
 * doesn't provide a real status renders exactly as before.
 */
enum class ConnectivityStatus {
    /** Validated internet at an acceptable speed — no banner. */
    Online,

    /** Reachable, but below the usable-speed threshold — "Bad internet connection". */
    BadConnection,

    /** No validated internet access — "No internet connection". */
    Offline,
}
