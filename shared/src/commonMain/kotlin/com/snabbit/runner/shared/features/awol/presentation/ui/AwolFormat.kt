package com.snabbit.runner.shared.features.awol.presentation.ui

import kotlin.math.roundToInt

/** `923` → `"15:23"` — the meter's MM:SS reading (minutes unpadded past 99 still render). */
internal fun formatAwolMmSs(totalSeconds: Int): String {
    val clamped = totalSeconds.coerceAtLeast(0)
    val minutes = clamped / 60
    val seconds = clamped % 60
    return "${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}"
}

/**
 * `850.0` → `"850m away"`, `3210.0` → `"3.2 km away"` — the hotspot tile's
 * distance line. Thresholds and rounding mirror the Dart precedent
 * (`cluster.dart` `distanceText`: whole metres under a km, one-decimal km
 * above) so the two stacks never disagree about the same fix; the suffix
 * comes from [com.snabbit.runner.shared.features.awol.domain.AwolStrings]
 * for the localization-swap convention.
 */
internal fun formatAwolDistance(meters: Double, awaySuffix: String): String {
    if (meters < 1000) return "${meters.roundToInt()}m $awaySuffix"
    // toStringAsFixed(1) parity without String.format (unavailable in commonMain).
    // Round through the /1000 km value (not meters/100) so the floating-point
    // representation matches Dart's `(m/1000).toStringAsFixed(1)` at exact
    // half-tenth boundaries (e.g. 1450 → "1.4 km", as Dart renders it).
    val tenths = (meters / 1000.0 * 10.0).roundToInt()
    return "${tenths / 10}.${tenths % 10} km $awaySuffix"
}
