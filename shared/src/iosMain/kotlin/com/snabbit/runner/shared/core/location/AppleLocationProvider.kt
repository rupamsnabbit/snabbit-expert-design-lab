package com.snabbit.runner.shared.core.location

import kotlinx.cinterop.ExperimentalForeignApi
import kotlinx.cinterop.useContents
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout
import platform.CoreLocation.CLLocation
import platform.CoreLocation.CLLocationManager
import platform.CoreLocation.CLLocationManagerDelegateProtocol
import platform.CoreLocation.kCLErrorDenied
import platform.CoreLocation.kCLLocationAccuracyBest
import platform.CoreLocation.kCLLocationAccuracyHundredMeters
import platform.CoreLocation.kCLLocationAccuracyNearestTenMeters
import platform.CoreLocation.kCLLocationAccuracyThreeKilometers
import platform.Foundation.NSDate
import platform.Foundation.NSError
import platform.Foundation.timeIntervalSince1970
import platform.darwin.NSObject
import kotlin.coroutines.resume

/**
 * iOS [LocationProvider] — a `CLLocationManager` wrapper (parity with Android's FusedLocationProvider).
 * Per the interface contract, permission is assumed already held (LocationServiceWrapper gates it);
 * this just maps CoreLocation to [LocationResult] (kCLErrorDenied → PermissionDenied, location
 * services off → ServiceDisabled, else Failure). `PlayServicesUnavailable` is never returned (Android-only).
 *
 * ⚠ Runtime device-verify only (authored without a full-Xcode build): async fixes arrive via a
 * retained [CLLocationManagerDelegateProtocol] on the main thread — confirm delegate retention +
 * the exact K/N symbol names on device.
 */
@OptIn(ExperimentalForeignApi::class)
internal class AppleLocationProvider : LocationProvider {

    // Shared manager for one-shot / last-known (retained so the weak delegate survives). trackLocation
    // builds its OWN manager+delegate per collector so each stream is independent (interface contract).
    private val delegate = LocationDelegate()
    private var managerRef: CLLocationManager? = null

    override suspend fun getCurrentLocation(config: TrackingConfig): LocationResult = withContext(Dispatchers.Main) {
        if (!CLLocationManager.locationServicesEnabled()) return@withContext LocationResult.ServiceDisabled
        val mgr = ensureManager().apply { desiredAccuracy = config.priority.toAccuracy() }
        try {
            withTimeout(config.timeoutMs) {
                suspendCancellableCoroutine<LocationResult> { cont ->
                    delegate.oneShot = { result ->
                        delegate.oneShot = null
                        if (cont.isActive) cont.resume(result)
                    }
                    cont.invokeOnCancellation { delegate.oneShot = null }
                    mgr.requestLocation()
                }
            }
        } catch (e: TimeoutCancellationException) {
            delegate.oneShot = null
            LocationResult.Failure("Location timeout after ${config.timeoutMs}ms", e)
        }
    }

    override suspend fun getLastKnownLocation(): LocationResult = withContext(Dispatchers.Main) {
        ensureManager().location?.let { LocationResult.Success(it.toModel()) }
            ?: LocationResult.Failure("No last known location")
    }

    override fun trackLocation(config: TrackingConfig): Flow<LocationResult> = callbackFlow {
        val streamDelegate = LocationDelegate().apply { stream = { trySend(it) } }
        val mgr = CLLocationManager().apply {
            delegate = streamDelegate
            desiredAccuracy = config.priority.toAccuracy()
        }
        mgr.startUpdatingLocation()
        // Transient CoreLocation errors are non-terminal (the OS keeps trying) — the stream stays
        // open; consumers apply their own staleness watchdog (per the interface's liveness caveat).
        awaitClose {
            mgr.stopUpdatingLocation()
            streamDelegate.stream = null
        }
    }.flowOn(Dispatchers.Main)

    override fun stopTracking() = Unit // collectors cancel the coroutine; awaitClose stops the updates

    private fun ensureManager(): CLLocationManager =
        managerRef ?: CLLocationManager().also { it.delegate = delegate; managerRef = it }
}

/** Bridges CoreLocation's delegate callbacks (one fix / stream / failure) to coroutines. */
@OptIn(ExperimentalForeignApi::class)
private class LocationDelegate : NSObject(), CLLocationManagerDelegateProtocol {
    var oneShot: ((LocationResult) -> Unit)? = null
    var stream: ((LocationResult) -> Unit)? = null

    override fun locationManager(manager: CLLocationManager, didUpdateLocations: List<*>) {
        val fix = (didUpdateLocations.lastOrNull() as? CLLocation)?.let { LocationResult.Success(it.toModel()) } ?: return
        oneShot?.invoke(fix)
        stream?.invoke(fix)
    }

    override fun locationManager(manager: CLLocationManager, didFailWithError: NSError) {
        // Only the one-shot path surfaces failures (so getCurrentLocation can return). Streams ignore
        // transient errors and stay open.
        oneShot?.invoke(mapError(didFailWithError))
    }
}

@OptIn(ExperimentalForeignApi::class)
private fun CLLocation.toModel(): SnabbitLocation {
    val now = (NSDate().timeIntervalSince1970 * 1000.0).toLong()
    val (lat, lng) = coordinate.useContents { latitude to longitude }
    return SnabbitLocation(
        latitude = lat,
        longitude = lng,
        accuracy = horizontalAccuracy.takeIf { it >= 0 }?.toFloat(),
        altitude = altitude.takeIf { verticalAccuracy > 0 },
        altitudeAccuracy = verticalAccuracy.takeIf { it > 0 }?.toFloat(),
        heading = course.takeIf { it >= 0 }?.toFloat(),
        speed = speed.takeIf { it >= 0 }?.toFloat(),
        speedAccuracy = speedAccuracy.takeIf { it >= 0 }?.toFloat(),
        isMocked = false, // CLLocation.sourceInformation.isSimulatedBySoftware is iOS 15+; not reported here.
        timestamp = (timestamp.timeIntervalSince1970 * 1000.0).toLong(),
        collectedAt = now,
    )
}

@OptIn(ExperimentalForeignApi::class)
private fun mapError(error: NSError): LocationResult =
    if (error.code == kCLErrorDenied.toLong()) LocationResult.PermissionDenied
    else LocationResult.Failure("CLLocationManager error ${error.code}: ${error.localizedDescription}")

private fun LocationPriority.toAccuracy(): Double = when (this) {
    LocationPriority.HIGH_ACCURACY -> kCLLocationAccuracyBest
    LocationPriority.BALANCED -> kCLLocationAccuracyNearestTenMeters
    LocationPriority.LOW_POWER -> kCLLocationAccuracyHundredMeters
    LocationPriority.PASSIVE -> kCLLocationAccuracyThreeKilometers
}
