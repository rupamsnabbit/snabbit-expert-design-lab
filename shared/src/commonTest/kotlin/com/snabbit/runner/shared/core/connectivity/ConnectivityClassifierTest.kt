package com.snabbit.runner.shared.core.connectivity

import kotlin.test.Test
import kotlin.test.assertEquals

/**
 * Branch coverage for [classifyConnectivity] — the pure decision behind the Android
 * [NetworkMonitor]. Uses the production ~1 Mbps threshold.
 */
class ConnectivityClassifierTest {

    private val threshold = 1_000

    @Test
    fun noValidatedInternet_isOffline_regardlessOfBandwidth() {
        assertEquals(ConnectivityStatus.Offline, classifyConnectivity(false, 50_000, threshold))
        assertEquals(ConnectivityStatus.Offline, classifyConnectivity(false, 0, threshold))
    }

    @Test
    fun validatedButBelowThreshold_isBadConnection() {
        assertEquals(ConnectivityStatus.BadConnection, classifyConnectivity(true, 1, threshold))
        assertEquals(ConnectivityStatus.BadConnection, classifyConnectivity(true, 999, threshold))
    }

    @Test
    fun validatedAtOrAboveThreshold_isOnline() {
        // Edge: exactly the threshold is Online, not bad.
        assertEquals(ConnectivityStatus.Online, classifyConnectivity(true, 1_000, threshold))
        assertEquals(ConnectivityStatus.Online, classifyConnectivity(true, 50_000, threshold))
    }

    @Test
    fun unknownBandwidth_isOnline_notBad() {
        // downstreamKbps <= 0 means the OS didn't report an estimate — treat as usable.
        assertEquals(ConnectivityStatus.Online, classifyConnectivity(true, 0, threshold))
        assertEquals(ConnectivityStatus.Online, classifyConnectivity(true, -1, threshold))
    }
}
