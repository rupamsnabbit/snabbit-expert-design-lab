package com.snabbit.runner.shared.core.connectivity

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.stateIn

/**
 * Android [NetworkMonitor] over [ConnectivityManager]'s default-network callback:
 * no validated internet → [ConnectivityStatus.Offline]; validated but the OS's estimated
 * downstream bandwidth is below [badThresholdKbps] → [ConnectivityStatus.BadConnection];
 * else [ConnectivityStatus.Online] (decision in [classifyConnectivity]).
 *
 * The callback is registered only while [status] is collected (`stateIn` + `WhileSubscribed`),
 * so an idle screen doesn't hold a network callback. Requires `ACCESS_NETWORK_STATE` (already
 * declared by the app; also used by the Flutter `connectivity_plus` layer). API 24+ for
 * [ConnectivityManager.registerDefaultNetworkCallback] — the app is minSdk 26.
 *
 * NOTE: [NetworkCapabilities.linkDownstreamBandwidthKbps] is a coarse capability estimate, not a
 * live throughput probe (see [classifyConnectivity]). Swap this impl for a latency-based one
 * behind [NetworkMonitor] if higher fidelity is needed — nothing else changes.
 */
class AndroidNetworkMonitor(
    context: Context,
    scope: CoroutineScope,
    private val badThresholdKbps: Int = DEFAULT_BAD_THRESHOLD_KBPS,
) : NetworkMonitor {

    private val connectivityManager =
        context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

    override val status: StateFlow<ConnectivityStatus> =
        callbackFlow {
            // Track the current default network's identity + its last-known capabilities so onLost
            // can tell a genuine drop (the default vanished, nothing replaced it) from a handover
            // (a new default already arrived). registerDefaultNetworkCallback delivers
            // onAvailable(new) BEFORE onLost(old), so on a Wi-Fi→cellular switch the default has
            // already moved on and the trailing onLost(old) must NOT flash Offline.
            var defaultNetwork: Network? = null
            var defaultCapabilities: NetworkCapabilities? = null

            fun emitCurrent() = trySend(defaultCapabilities.toStatus(badThresholdKbps))

            val callback = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    // A new default arrived; its capabilities follow via onCapabilitiesChanged.
                    // Adopt the identity now so a trailing onLost(old) is recognised as a handover.
                    defaultNetwork = network
                }

                override fun onCapabilitiesChanged(
                    network: Network,
                    networkCapabilities: NetworkCapabilities,
                ) {
                    defaultNetwork = network
                    defaultCapabilities = networkCapabilities
                    emitCurrent()
                }

                override fun onLost(network: Network) {
                    // Only the CURRENT default going away means we're offline. A lost non-default
                    // network is the old link after a handover (its replacement already arrived) —
                    // ignore it so a clean Wi-Fi→cellular switch doesn't flash Offline.
                    if (network != defaultNetwork) return
                    defaultNetwork = null
                    defaultCapabilities = null
                    emitCurrent()
                }

                override fun onUnavailable() {
                    defaultNetwork = null
                    defaultCapabilities = null
                    emitCurrent()
                }
            }
            // Seed identity + status from the active network so a fresh collector isn't stuck and
            // an immediate onLost is attributed to the right network.
            defaultNetwork = connectivityManager.activeNetwork
            defaultCapabilities = defaultNetwork?.let(connectivityManager::getNetworkCapabilities)
            emitCurrent()
            connectivityManager.registerDefaultNetworkCallback(callback)
            awaitClose { connectivityManager.unregisterNetworkCallback(callback) }
        }
            .distinctUntilChanged()
            .stateIn(
                scope = scope,
                started = SharingStarted.WhileSubscribed(5_000),
                initialValue = currentCapabilities().toStatus(badThresholdKbps),
            )

    private fun currentCapabilities(): NetworkCapabilities? =
        connectivityManager.activeNetwork?.let(connectivityManager::getNetworkCapabilities)

    companion object {
        /** ~1 Mbps: below this the OS-estimated downstream link is flagged "bad". */
        const val DEFAULT_BAD_THRESHOLD_KBPS: Int = 1_000
    }
}

private fun NetworkCapabilities?.toStatus(thresholdKbps: Int): ConnectivityStatus {
    if (this == null) return ConnectivityStatus.Offline
    val hasValidatedInternet =
        hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
            hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
    return classifyConnectivity(
        hasValidatedInternet = hasValidatedInternet,
        downstreamKbps = linkDownstreamBandwidthKbps,
        thresholdKbps = thresholdKbps,
    )
}
