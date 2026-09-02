package com.snabbit.runner.shared.core.permissions

import kotlinx.cinterop.ExperimentalForeignApi
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import platform.AVFAudio.AVAudioSession
import platform.AVFAudio.AVAudioSessionRecordPermission
import platform.AVFAudio.AVAudioSessionRecordPermissionDenied
import platform.AVFAudio.AVAudioSessionRecordPermissionGranted
import platform.CoreLocation.CLAuthorizationStatus
import platform.CoreLocation.CLLocationManager
import platform.CoreLocation.CLLocationManagerDelegateProtocol
import platform.CoreLocation.kCLAuthorizationStatusAuthorizedAlways
import platform.CoreLocation.kCLAuthorizationStatusAuthorizedWhenInUse
import platform.CoreLocation.kCLAuthorizationStatusDenied
import platform.CoreLocation.kCLAuthorizationStatusNotDetermined
import platform.CoreLocation.kCLAuthorizationStatusRestricted
import platform.CoreLocation.CLAccuracyAuthorization
import platform.Foundation.NSURL
import platform.UIKit.UIApplication
import platform.UIKit.UIApplicationOpenSettingsURLString
import platform.darwin.NSObject
import platform.darwin.dispatch_async
import platform.darwin.dispatch_get_main_queue
import kotlin.coroutines.resume

/**
 * iOS [PermissionManager] — Kavach scope (microphone + location). Other [SnabbitPermission] cases
 * return NOT_AVAILABLE (no iOS consumer yet). DENIED vs DENIED_ALWAYS comes straight from the iOS
 * authorization status (no "was-requested" flag needed, unlike Android). iOS 14+ (CoreLocation
 * instance `authorizationStatus` + the iOS-14 delegate); mic via AVAudioSession (works 12+).
 *
 * ⚠ Runtime device-verify only (authored without a full-Xcode build): the location request is async
 * via a retained [CLLocationManagerDelegateProtocol] on the main thread — confirm delegate retention,
 * the two-step Always upgrade, and the exact Kotlin/Native symbol names on device.
 */
@OptIn(ExperimentalForeignApi::class)
internal class IosPermissionManager : PermissionManager {

    // Retained so CoreLocation's weak delegate isn't deallocated (the auth callback would never fire).
    private val locationDelegate = LocationAuthDelegate()
    private var locationManagerRef: CLLocationManager? = null

    override suspend fun check(permission: SnabbitPermission): PermissionStatus = when (permission) {
        SnabbitPermission.Microphone -> mapMic(AVAudioSession.sharedInstance().recordPermission)
        SnabbitPermission.LocationFine, SnabbitPermission.LocationCoarse ->
            mapLocation(locationStatus(), background = false)
        SnabbitPermission.LocationBackground -> mapLocation(locationStatus(), background = true)
        else -> PermissionStatus.NOT_AVAILABLE
    }

    override suspend fun request(permission: SnabbitPermission): PermissionStatus = when (permission) {
        SnabbitPermission.Microphone -> requestMic()
        SnabbitPermission.LocationFine, SnabbitPermission.LocationCoarse -> requestLocation(background = false)
        SnabbitPermission.LocationBackground -> requestLocation(background = true)
        else -> PermissionStatus.NOT_AVAILABLE
    }

    override fun requestMultiple(
        permissions: List<SnabbitPermission>,
    ): Flow<Pair<SnabbitPermission, PermissionStatus>> = flow {
        permissions.forEach { emit(it to request(it)) }
    }

    /** iOS has no "show rationale" concept — the status alone drives the UI (DENIED vs DENIED_ALWAYS). */
    override fun shouldShowRationale(permission: SnabbitPermission): Boolean = false

    override fun isPreciseLocationGranted(): Boolean =
        locationManagerRef?.accuracyAuthorization == CLAccuracyAuthorization.CLAccuracyAuthorizationFullAccuracy

    override fun openSettings() {
        val url = NSURL.URLWithString(UIApplicationOpenSettingsURLString) ?: return
        dispatch_async(dispatch_get_main_queue()) {
            UIApplication.sharedApplication.openURL(url, options = emptyMap<Any?, Any>(), completionHandler = null)
        }
    }

    override fun isServiceEnabled(service: ServiceType): Boolean = when (service) {
        ServiceType.GPS -> CLLocationManager.locationServicesEnabled()
        ServiceType.CAMERA, ServiceType.MICROPHONE -> true // hardware always present on iOS devices
    }

    override fun checkAdminPolicy(): AdminPolicyInfo = AdminPolicyInfo.NONE // no iOS DevicePolicyManager equivalent

    // --- microphone (AVAudioSession) ---

    private fun mapMic(permission: AVAudioSessionRecordPermission): PermissionStatus = when (permission) {
        AVAudioSessionRecordPermissionGranted -> PermissionStatus.GRANTED
        AVAudioSessionRecordPermissionDenied -> PermissionStatus.DENIED_ALWAYS // iOS can't re-prompt → Settings
        else -> PermissionStatus.DENIED // undetermined — retryable (request shows the prompt)
    }

    private suspend fun requestMic(): PermissionStatus {
        val session = AVAudioSession.sharedInstance()
        return when (session.recordPermission) {
            AVAudioSessionRecordPermissionGranted -> PermissionStatus.GRANTED
            AVAudioSessionRecordPermissionDenied -> PermissionStatus.DENIED_ALWAYS
            else -> suspendCancellableCoroutine { cont ->
                session.requestRecordPermission {
                    // Re-read the real post-prompt status (granted / denied) rather than assuming —
                    // maps correct-by-construction, matching check()'s mapping.
                    if (cont.isActive) cont.resume(mapMic(session.recordPermission))
                }
            }
        }
    }

    // --- location (CLLocationManager) ---

    private suspend fun locationStatus(): CLAuthorizationStatus =
        withContext(Dispatchers.Main) { ensureManager().authorizationStatus }

    private suspend fun requestLocation(background: Boolean): PermissionStatus = withContext(Dispatchers.Main) {
        val mgr = ensureManager()
        when (val status = mgr.authorizationStatus) {
            kCLAuthorizationStatusNotDetermined -> mapLocation(
                awaitAuthChange {
                    if (background) mgr.requestAlwaysAuthorization() else mgr.requestWhenInUseAuthorization()
                },
                background,
            )
            // Foreground already granted, background needed → request the Always upgrade but DON'T
            // await the delegate: on iOS 13+ the status doesn't change in-session (iOS grants
            // provisional Always and defers the real prompt to backgrounding), so awaiting the
            // delegate hangs forever and bricks activation. Fire the request and return the current
            // status now; the ON_RESUME permission re-check reconciles the eventual grant (#6195).
            kCLAuthorizationStatusAuthorizedWhenInUse ->
                if (background) {
                    mgr.requestAlwaysAuthorization()
                    mapLocation(mgr.authorizationStatus, background)
                } else {
                    PermissionStatus.GRANTED
                }
            else -> mapLocation(status, background)
        }
    }

    /** Suspend until the delegate reports the next authorization change, then clear the hook. */
    private suspend fun awaitAuthChange(trigger: () -> Unit): CLAuthorizationStatus =
        suspendCancellableCoroutine { cont ->
            locationDelegate.onChange = { status ->
                locationDelegate.onChange = null
                if (cont.isActive) cont.resume(status)
            }
            cont.invokeOnCancellation { locationDelegate.onChange = null }
            trigger()
        }

    private fun mapLocation(status: CLAuthorizationStatus, background: Boolean): PermissionStatus = when (status) {
        kCLAuthorizationStatusAuthorizedAlways -> PermissionStatus.GRANTED
        kCLAuthorizationStatusAuthorizedWhenInUse ->
            if (background) PermissionStatus.DENIED else PermissionStatus.GRANTED // WhenInUse ≠ background
        kCLAuthorizationStatusNotDetermined -> PermissionStatus.DENIED // retryable
        kCLAuthorizationStatusDenied, kCLAuthorizationStatusRestricted -> PermissionStatus.DENIED_ALWAYS
        else -> PermissionStatus.NOT_AVAILABLE
    }

    /** Create-once on the main thread; sets the retained delegate. */
    private fun ensureManager(): CLLocationManager =
        locationManagerRef ?: CLLocationManager().also {
            it.delegate = locationDelegate
            locationManagerRef = it
        }
}

/** Bridges CoreLocation's delegate-only authorization callback to a coroutine. */
@OptIn(ExperimentalForeignApi::class)
private class LocationAuthDelegate : NSObject(), CLLocationManagerDelegateProtocol {
    var onChange: ((CLAuthorizationStatus) -> Unit)? = null

    override fun locationManagerDidChangeAuthorization(manager: CLLocationManager) {
        onChange?.invoke(manager.authorizationStatus)
    }
}
