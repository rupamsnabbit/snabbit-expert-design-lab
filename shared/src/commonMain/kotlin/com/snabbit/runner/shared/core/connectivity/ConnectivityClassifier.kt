package com.snabbit.runner.shared.core.connectivity

/**
 * Pure mapping from a network snapshot to a [ConnectivityStatus], factored out of the
 * Android [NetworkMonitor] so the threshold logic is unit-testable without platform APIs.
 *
 * @param hasValidatedInternet the active transport reports actual, validated internet
 *   access (Android `NET_CAPABILITY_INTERNET` + `NET_CAPABILITY_VALIDATED`).
 * @param downstreamKbps the OS's **estimated** downstream bandwidth in kbps. This is a
 *   coarse capability hint, not a live throughput measurement — treat it as a floor.
 *   `<= 0` means "unknown", which is deliberately NOT treated as bad (don't cry wolf).
 * @param thresholdKbps below this (and above 0) the link is flagged [BadConnection].
 *   ~1 Mbps by default: sub-1 Mbps is widely considered poor for interactive mobile use
 *   (1–5 Mbps usable, 5 Mbps+ good).
 */
fun classifyConnectivity(
    hasValidatedInternet: Boolean,
    downstreamKbps: Int,
    thresholdKbps: Int,
): ConnectivityStatus = when {
    !hasValidatedInternet -> ConnectivityStatus.Offline
    downstreamKbps in 1 until thresholdKbps -> ConnectivityStatus.BadConnection
    else -> ConnectivityStatus.Online
}
