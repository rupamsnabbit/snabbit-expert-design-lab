package com.snabbit.runner.shared.core.location

/**
 * Per-call location parameters. The module owns NO intervals or runner-status mapping — the
 * consumer (e.g. the IoT module, reading remote config) constructs this and passes it in.
 *
 * @property priority   accuracy/power trade-off for the request.
 * @property intervalMs  desired interval between updates for [LocationProvider.trackLocation]
 *                       (ignored by the one-shot calls). Default matches the current geolocator
 *                       setup. NOTE: the Android impl sets FLP's *fastest* update interval to
 *                       `intervalMs / 2`, so a ready fix may arrive up to ~2× sooner than this — a
 *                       deliberate freshness trade-off, not a guaranteed cadence. No distance
 *                       filter is applied (the geolocator streams this replaces use none either).
 * @property timeoutMs   max wait for [LocationProvider.getCurrentLocation] before it returns
 *                       [LocationResult.Failure]. Default matches the IoT collector's 30s limit.
 */
data class TrackingConfig(
    val priority: LocationPriority = LocationPriority.HIGH_ACCURACY,
    val intervalMs: Long = 5_000,
    val timeoutMs: Long = 30_000,
)

/** Accuracy/power profile; maps to Google Play services `Priority` constants on Android. */
enum class LocationPriority {
    /** GPS + WiFi + cell (~10 m). */
    HIGH_ACCURACY,

    /** WiFi + cell (~40–300 m). */
    BALANCED,

    /** Cell only (~300 m–3 km). */
    LOW_POWER,

    /** No active requests — only receives updates other apps trigger. */
    PASSIVE,
}
