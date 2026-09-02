package com.snabbit.runner.shared.features.shift

import com.snabbit.runner.shared.core.location.LocationProvider
import com.snabbit.runner.shared.core.location.LocationResult
import com.snabbit.runner.shared.core.location.SnabbitLocation
import com.snabbit.runner.shared.core.location.TrackingConfig
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.emptyFlow

/**
 * Test fake for [LocationProvider]. Only [getCurrentLocation] / [getLastKnownLocation]
 * are wired — the shift-login flow uses the default [LocationProvider.getCurrentOrLastKnown]
 * which composes from those two. Streaming methods return empty / no-op.
 */
class FakeLocationProvider(
    private var current: LocationResult = LocationResult.Success(DEFAULT_LOC),
    private var lastKnown: LocationResult = LocationResult.Success(DEFAULT_LOC),
) : LocationProvider {

    fun setCurrent(result: LocationResult) { current = result }

    override suspend fun getCurrentLocation(config: TrackingConfig): LocationResult = current
    override suspend fun getLastKnownLocation(): LocationResult = lastKnown
    override fun trackLocation(config: TrackingConfig): Flow<LocationResult> = emptyFlow()
    override fun stopTracking() = Unit

    companion object {
        val DEFAULT_LOC = SnabbitLocation(
            latitude = 12.9716,
            longitude = 77.5946,
            accuracy = 10f,
            timestamp = 0L,
            collectedAt = 0L,
        )
    }
}
