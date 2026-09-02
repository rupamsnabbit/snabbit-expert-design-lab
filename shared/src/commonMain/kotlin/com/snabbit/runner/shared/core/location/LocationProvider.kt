package com.snabbit.runner.shared.core.location

import kotlinx.coroutines.flow.Flow

/**
 * The single entry point for location retrieval (Facade). Platform implementations wrap
 * FusedLocationProviderClient (Android) / CLLocationManager (iOS, later). Every method is
 * exception-safe: an unexpected platform error resolves to a [LocationResult] value
 * (with diagnostics), never a crash.
 *
 * Permission checking is layered on by [LocationServiceWrapper] (the bound implementation),
 * so direct platform providers assume the caller already holds permission.
 */
interface LocationProvider {

    /**
     * One fresh fix, no fallback. Checks Play services → resolves GPS settings (may show the
     * system "turn on location" dialog) → FLP `getCurrentLocation` with [TrackingConfig.timeoutMs].
     * Returns [LocationResult.Failure] on timeout/null/error.
     *
     * Note: [TrackingConfig.timeoutMs] bounds only the fix-acquisition step. The optional
     * GPS-settings dialog is a user interaction and is NOT time-bounded here — it is resolved when
     * the user responds (or when the Activity is destroyed). Callers that need a hard overall
     * ceiling should wrap the call in their own timeout.
     */
    suspend fun getCurrentLocation(config: TrackingConfig = TrackingConfig()): LocationResult

    /** The cached last-known fix. No active GPS scan — fast, may be stale or absent. */
    suspend fun getLastKnownLocation(): LocationResult

    /**
     * A continuous stream of fixes. Each collector gets an independent stream (no shared state).
     *
     * Within the stream, [LocationResult.ServiceDisabled] is NON-terminal: it is emitted if GPS is
     * turned off mid-stream and the stream stays open, so updates resume automatically if it is
     * re-enabled. Treat it as "GPS currently off", not "tracking ended".
     *
     * Liveness caveat: a fix is delivered only while FLP can produce one. If the stream goes silent
     * (no signal, provider starvation, or a mid-stream permission revocation the OS doesn't surface
     * via an availability callback), no value is emitted and the Flow stays open. Consumers that must
     * detect a stall MUST apply their own staleness watchdog on [SnabbitLocation.timestamp] — this
     * module is a stateless primitive; cadence/staleness is the consumer's concern.
     */
    fun trackLocation(config: TrackingConfig = TrackingConfig()): Flow<LocationResult>

    /**
     * Kept for interface symmetry; collectors stop tracking by cancelling the coroutine collecting
     * [trackLocation] (each stream cleans itself up via `awaitClose`).
     */
    fun stopTracking()

    /**
     * Best effort: try [getCurrentLocation]; on a recoverable miss fall back to [getLastKnownLocation].
     * Mirrors the Flutter IoT collector / check-in behaviour (fresh preferred, cached acceptable).
     *
     * Short-circuits on [LocationResult.PermissionDenied] and [LocationResult.PlayServicesUnavailable]
     * — last-known needs both too, so retrying is pointless. Falls back on
     * [LocationResult.Failure]/[LocationResult.ServiceDisabled] (the cache needs neither a GPS fix
     * nor an enabled service).
     *
     * Note: a [LocationResult.Success] from the fallback is a CACHED fix that may be stale (e.g. the
     * user just declined the GPS-enable dialog → [LocationResult.ServiceDisabled] → cached fix). The
     * "fresh vs cached" distinction is intentionally collapsed here; callers sensitive to freshness
     * must check [SnabbitLocation.timestamp]/[SnabbitLocation.collectedAt], or call
     * [getCurrentLocation] directly (which preserves the distinct terminal reasons).
     */
    suspend fun getCurrentOrLastKnown(config: TrackingConfig = TrackingConfig()): LocationResult =
        when (val result = getCurrentLocation(config)) {
            is LocationResult.Success,
            LocationResult.PermissionDenied,
            LocationResult.PlayServicesUnavailable -> result
            is LocationResult.Failure,
            LocationResult.ServiceDisabled -> getLastKnownLocation()
        }
}
