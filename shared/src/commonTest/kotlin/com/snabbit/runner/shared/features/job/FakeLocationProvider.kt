package com.snabbit.runner.shared.features.job

import com.snabbit.runner.shared.features.job.data.LocationProvider
import com.snabbit.runner.shared.features.job.domain.model.JobLocation

/** Test [LocationProvider] — returns a fixed location (or null to simulate denied/unavailable). */
class FakeLocationProvider(
    private val location: JobLocation? = JobLocation(1.0, 2.0),
) : LocationProvider {
    override suspend fun currentLocation(): JobLocation? = location
}
