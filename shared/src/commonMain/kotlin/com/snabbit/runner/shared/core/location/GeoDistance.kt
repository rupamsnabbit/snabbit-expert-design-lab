package com.snabbit.runner.shared.core.location

import kotlin.math.asin
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * Equatorial Earth radius in metres — the same constant geolocator's
 * `distanceBetween` uses, so distances shown by shared code match what the
 * Dart side (e.g. job_login's "away" label) computes for the same fix.
 */
private const val EARTH_RADIUS_METERS = 6_378_137.0

private const val DEGREES_TO_RADIANS = kotlin.math.PI / 180.0

/**
 * Great-circle distance in metres between two WGS84 coordinates (haversine).
 *
 * Pure `kotlin.math` — no platform APIs, safe in commonMain. Symmetric in its
 * endpoints; identical points return 0.0. Callers own presentation (rounding,
 * unit choice, staleness of the fix).
 */
fun distanceMeters(
    startLatitude: Double,
    startLongitude: Double,
    endLatitude: Double,
    endLongitude: Double,
): Double {
    val latDelta = (endLatitude - startLatitude) * DEGREES_TO_RADIANS
    val lngDelta = (endLongitude - startLongitude) * DEGREES_TO_RADIANS
    val a = sin(latDelta / 2) * sin(latDelta / 2) +
        cos(startLatitude * DEGREES_TO_RADIANS) * cos(endLatitude * DEGREES_TO_RADIANS) *
        sin(lngDelta / 2) * sin(lngDelta / 2)
    // Clamp guards the asin domain against floating-point drift on antipodes.
    return 2 * EARTH_RADIUS_METERS * asin(sqrt(min(a, 1.0)))
}
