package com.snabbit.runner.shared.core.location.fakes

import com.snabbit.runner.shared.core.location.LocationProvider
import com.snabbit.runner.shared.core.location.LocationResult
import com.snabbit.runner.shared.core.location.TrackingConfig
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.asFlow

/**
 * Programmable [LocationProvider] double. Records call counts and the last [TrackingConfig] seen,
 * so tests can assert delegation and short-circuiting. Also the double future IoT-module tests use.
 *
 * [getCurrentOrLastKnown] is intentionally NOT overridden — tests exercise the real interface
 * default against [currentResult]/[lastKnownResult].
 */
class FakeLocationProvider(
    var currentResult: LocationResult = LocationResult.Failure("currentResult not set"),
    var lastKnownResult: LocationResult = LocationResult.Failure("lastKnownResult not set"),
    var trackResults: List<LocationResult> = emptyList(),
) : LocationProvider {

    var getCurrentLocationCalls = 0
        private set
    var getLastKnownLocationCalls = 0
        private set
    var trackLocationCalls = 0
        private set
    var stopTrackingCalls = 0
        private set
    var lastConfig: TrackingConfig? = null
        private set

    override suspend fun getCurrentLocation(config: TrackingConfig): LocationResult {
        getCurrentLocationCalls++
        lastConfig = config
        return currentResult
    }

    override suspend fun getLastKnownLocation(): LocationResult {
        getLastKnownLocationCalls++
        return lastKnownResult
    }

    override fun trackLocation(config: TrackingConfig): Flow<LocationResult> {
        trackLocationCalls++
        lastConfig = config
        return trackResults.asFlow()
    }

    override fun stopTracking() {
        stopTrackingCalls++
    }
}
