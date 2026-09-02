package com.snabbit.runner.shared.core.location.internal

import android.location.Location
import android.os.Build
import com.snabbit.runner.shared.core.location.SnabbitLocation

/**
 * Maps an Android [Location] to our [SnabbitLocation]. Same approach as geolocator's
 * `LocationMapper`: guard every optional field with its `has*()` so an unset value maps to `null`
 * (not a misleading 0). minSdk is 26, so the vertical/bearing/speed-accuracy getters (API 26+) are
 * always available — no version check needed for those.
 */
internal fun Location.toModel(): SnabbitLocation = SnabbitLocation(
    latitude = latitude,
    longitude = longitude,
    accuracy = if (hasAccuracy()) accuracy else null,
    altitude = if (hasAltitude()) altitude else null,
    altitudeAccuracy = if (hasVerticalAccuracy()) verticalAccuracyMeters else null,
    heading = if (hasBearing()) bearing else null,
    headingAccuracy = if (hasBearingAccuracy()) bearingAccuracyDegrees else null,
    speed = if (hasSpeed()) speed else null,
    speedAccuracy = if (hasSpeedAccuracy()) speedAccuracyMetersPerSecond else null,
    // Mock detection: isMock (API 31+) replaced the deprecated isFromMockProvider. Same approach
    // as geolocator + Namma Yatri — direct OS API, reported (not filtered).
    isMocked = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) isMock
    else @Suppress("DEPRECATION") isFromMockProvider,
    timestamp = time,
    collectedAt = System.currentTimeMillis(),
)
