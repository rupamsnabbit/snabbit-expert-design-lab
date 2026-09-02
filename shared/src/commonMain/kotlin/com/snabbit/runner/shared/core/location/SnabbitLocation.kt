package com.snabbit.runner.shared.core.location

/**
 * A single location fix, platform-agnostic.
 *
 * Named `SnabbitLocation` (not `Location`) to avoid colliding with `android.location.Location`
 * in the Android mapper. Optional fields are `null` when the underlying platform fix did not
 * report them (mirrors geolocator's `has*()`-guarded mapping) — callers must treat absent values
 * as "unknown", never as zero.
 *
 * Accuracy/altitude/heading/speed are passed through raw — this module does NO validation,
 * smoothing, or classification (Atlas/IoT own that). `isMocked` is reported, never filtered.
 */
data class SnabbitLocation(
    /** Degrees. */
    val latitude: Double,
    /** Degrees. */
    val longitude: Double,
    /** Horizontal accuracy radius in metres (68% confidence). `null` if the fix had none. */
    val accuracy: Float?,
    /** Metres above the WGS84 ellipsoid. */
    val altitude: Double? = null,
    /** Vertical accuracy in metres (API 26+). */
    val altitudeAccuracy: Float? = null,
    /** Direction of travel in degrees (0..360). */
    val heading: Float? = null,
    /** Heading accuracy in degrees (API 26+). */
    val headingAccuracy: Float? = null,
    /** Ground speed in metres/second. */
    val speed: Float? = null,
    /** Speed accuracy in metres/second (API 26+). */
    val speedAccuracy: Float? = null,
    /** Whether the OS flagged this fix as coming from a mock provider. Reported, not filtered. */
    val isMocked: Boolean = false,
    /** Epoch millis from the location hardware (the fix's own timestamp). */
    val timestamp: Long,
    /** Epoch millis when this module mapped the fix (wall clock at processing time). */
    val collectedAt: Long,
)
