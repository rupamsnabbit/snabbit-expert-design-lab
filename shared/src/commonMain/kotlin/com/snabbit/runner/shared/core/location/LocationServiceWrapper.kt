package com.snabbit.runner.shared.core.location

import com.snabbit.runner.shared.core.permissions.PermissionManager
import com.snabbit.runner.shared.core.permissions.PermissionStatus
import com.snabbit.runner.shared.core.permissions.SnabbitPermission
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.emitAll
import kotlinx.coroutines.flow.flow

/**
 * Decorator that gates every [LocationProvider] call behind a fine-location permission check
 * (via the snabbit-permissions [PermissionManager]). If the permission is not
 * [PermissionStatus.GRANTED], the call returns [LocationResult.PermissionDenied] without ever
 * touching the platform provider.
 *
 * This is the [LocationProvider] bound in Koin; the raw FusedLocationProvider sits behind it.
 * [getCurrentOrLastKnown] is inherited from the interface default — it composes the two gated
 * primitives, so it needs no override.
 */
class LocationServiceWrapper(
    private val provider: LocationProvider,
    private val permissionManager: PermissionManager,
) : LocationProvider {

    private suspend fun hasLocationPermission(): Boolean =
        permissionManager.check(SnabbitPermission.LocationFine) == PermissionStatus.GRANTED

    override suspend fun getCurrentLocation(config: TrackingConfig): LocationResult =
        if (hasLocationPermission()) provider.getCurrentLocation(config)
        else LocationResult.PermissionDenied

    override suspend fun getLastKnownLocation(): LocationResult =
        if (hasLocationPermission()) provider.getLastKnownLocation()
        else LocationResult.PermissionDenied

    override fun trackLocation(config: TrackingConfig): Flow<LocationResult> = flow {
        if (!hasLocationPermission()) {
            emit(LocationResult.PermissionDenied)
            return@flow
        }
        emitAll(provider.trackLocation(config))
    }

    override fun stopTracking() = provider.stopTracking()
}
