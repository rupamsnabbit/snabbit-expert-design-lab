package com.snabbit.runner.shared.core.location

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.location.LocationManager
import android.os.Looper
import androidx.activity.ComponentActivity
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.IntentSenderRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import androidx.core.location.LocationManagerCompat
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import com.google.android.gms.common.api.ApiException
import com.google.android.gms.common.api.ResolvableApiException
import com.google.android.gms.location.LocationAvailability
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.LocationSettingsRequest
import com.google.android.gms.location.LocationSettingsStatusCodes
import com.google.android.gms.location.LocationResult as GmsLocationResult
import com.google.android.gms.tasks.CancellationTokenSource
import com.snabbit.runner.shared.core.location.internal.toGmsPriority
import com.snabbit.runner.shared.core.location.internal.toModel
import com.snabbit.runner.shared.core.CrashReporter
import kotlinx.coroutines.CancellableContinuation
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.withContext
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withTimeout
import java.lang.ref.WeakReference
import kotlin.coroutines.resume

/**
 * Android [LocationProvider] over [com.google.android.gms.location.FusedLocationProviderClient].
 * Mirrors the permission module's `AndroidPermissionManager`: exception-safe (every escape →
 * a [LocationResult] value + [CrashReporter], never a crash — except [CancellationException],
 * which is always rethrown), and implements [LocationAttachable] so the host Activity registers
 * the GPS-settings-dialog launcher in `onCreate` (before STARTED).
 *
 * Runtime location permission is NOT checked here — [LocationServiceWrapper] is the gate, so the
 * platform calls are annotated [SuppressLint] `MissingPermission`.
 */
@SuppressLint("MissingPermission")
internal class FusedLocationProvider(
    private val context: Context,
    private val crashReporter: CrashReporter,
) : LocationProvider, LocationAttachable {

    private val client = LocationServices.getFusedLocationProviderClient(context)
    private val settingsClient = LocationServices.getSettingsClient(context)

    private var activityRef: WeakReference<ComponentActivity>? = null
    private var settingsLauncher: ActivityResultLauncher<IntentSenderRequest>? = null

    // Single in-flight GPS-settings dialog; resumed from the launcher callback.
    private var pendingSettingsResolution: CancellableContinuation<Boolean>? = null

    // --- LocationAttachable ---

    override fun attachActivity(activity: ComponentActivity) {
        if (activityRef?.get() === activity) return // already attached to this instance
        // Self-heal (mirrors AndroidPermissionManager): re-attaching to a NEW Activity without a
        // prior detach() (config-change/process-death recreation where onDestroy's detach was
        // missed or raced) would otherwise leak the old launcher and strand an in-flight
        // GPS-dialog continuation bound to the dead launcher (hang forever).
        releaseActivityState()
        activityRef = WeakReference(activity)
        try {
            settingsLauncher = activity.registerForActivityResult(
                ActivityResultContracts.StartIntentSenderForResult(),
            ) { result -> onSettingsResolution(result.resultCode == Activity.RESULT_OK) }
        } catch (t: Throwable) {
            // Registering after STARTED throws — surface it; attach earlier (onCreate).
            crashReporter.report(t, mapOf("op" to "location attachActivity: launcher registration failed"))
        }
    }

    override fun detach() = releaseActivityState()

    /**
     * Resume/clear any in-flight settings dialog and release the launcher + Activity ref. Called
     * from both [detach] (onDestroy) and [attachActivity] (defensive, before re-registering on a
     * new instance), so a missed/raced detach can never strand the suspended resolveSettings — its
     * awaiting caller always gets a result instead of hanging.
     */
    private fun releaseActivityState() {
        // Resume any in-flight resolution before the launcher dies with the Activity — otherwise
        // its suspended checkAndResolveSettings (and the awaiting caller) would hang forever.
        pendingSettingsResolution?.let { if (it.isActive) it.resume(false) }
        pendingSettingsResolution = null
        settingsLauncher?.unregister()
        settingsLauncher = null
        activityRef = null
    }

    private fun onSettingsResolution(granted: Boolean) {
        val cont = pendingSettingsResolution
        pendingSettingsResolution = null
        if (cont != null && cont.isActive) cont.resume(granted)
    }

    // --- LocationProvider ---

    override suspend fun getCurrentLocation(config: TrackingConfig): LocationResult {
        if (!isPlayServicesAvailable()) return LocationResult.PlayServicesUnavailable
        if (!checkAndResolveSettings(config)) return LocationResult.ServiceDisabled

        // withTimeout cancels the coroutine on expiry → await() throws → we cancel the
        // CancellationTokenSource so FLP stops the GPS search. .await() takes NO argument.
        val cancellation = CancellationTokenSource()
        return try {
            withTimeout(config.timeoutMs) {
                val location = client
                    .getCurrentLocation(config.priority.toGmsPriority(), cancellation.token)
                    .await()
                if (location != null) LocationResult.Success(location.toModel())
                else LocationResult.Failure("getCurrentLocation returned null")
            }
        } catch (e: TimeoutCancellationException) {
            cancellation.cancel()
            LocationResult.Failure("Location timeout after ${config.timeoutMs}ms", e)
        } catch (c: CancellationException) {
            cancellation.cancel()
            throw c // never swallow structured coroutine cancellation
        } catch (t: Throwable) {
            cancellation.cancel()
            crashReporter.report(t, mapOf("op" to "getCurrentLocation"))
            LocationResult.Failure("getCurrentLocation failed: ${t.summary()}", t)
        }
    }

    override suspend fun getLastKnownLocation(): LocationResult {
        if (!isPlayServicesAvailable()) return LocationResult.PlayServicesUnavailable
        return try {
            val location = client.lastLocation.await()
            if (location != null) LocationResult.Success(location.toModel())
            else LocationResult.Failure("No last known location")
        } catch (c: CancellationException) {
            throw c
        } catch (t: Throwable) {
            crashReporter.report(t, mapOf("op" to "getLastKnownLocation"))
            LocationResult.Failure("getLastKnownLocation failed: ${t.summary()}", t)
        }
    }

    override fun trackLocation(config: TrackingConfig): Flow<LocationResult> = callbackFlow {
        if (!isPlayServicesAvailable()) {
            trySend(LocationResult.PlayServicesUnavailable)
            close()
            return@callbackFlow
        }
        if (!checkAndResolveSettings(config)) {
            trySend(LocationResult.ServiceDisabled)
            close()
            return@callbackFlow
        }

        val request = LocationRequest.Builder(config.priority.toGmsPriority(), config.intervalMs)
            // Fastest interval = half the desired interval: lets FLP surface a ready fix up to ~2×
            // sooner than intervalMs (fresher updates) without requesting a faster base cadence.
            // Documented on TrackingConfig.intervalMs. No distance filter — the geolocator streams
            // this replaces use none either (LocationSettings default distanceFilter = 0).
            .setMinUpdateIntervalMillis(config.intervalMs / 2)
            .build()

        // Each collector gets its OWN callback — no shared state, safe for concurrent collectors.
        val callback = object : LocationCallback() {
            override fun onLocationResult(result: GmsLocationResult) {
                result.lastLocation?.let { location ->
                    // trySend never blocks. If the buffer is full / the channel is closing, the
                    // update is dropped and FLP delivers the next one — intentionally not surfaced.
                    trySend(LocationResult.Success(location.toModel()))
                }
            }

            // Fires on availability transitions (rare) — NOT per fix — so the checks below add no
            // per-update cost. When FLP can't deliver, distinguish WHY with cheap synchronous reads:
            //  - permission revoked mid-stream → PermissionDenied + close (terminal; can't recover);
            //  - GPS service off → ServiceDisabled, but NON-terminal: the stream stays open and
            //    updates resume automatically if GPS is re-enabled (treat as "GPS currently off");
            //  - transient provider switch ("likely but not guaranteed" per Google) → ignore.
            override fun onLocationAvailability(availability: LocationAvailability) {
                if (availability.isLocationAvailable) return
                if (!hasFineLocationPermission()) {
                    trySend(LocationResult.PermissionDenied)
                    close()
                    return
                }
                if (!isLocationServiceEnabled()) {
                    trySend(LocationResult.ServiceDisabled)
                }
            }
        }

        try {
            client.requestLocationUpdates(request, callback, Looper.getMainLooper())
        } catch (t: Throwable) {
            crashReporter.report(t, mapOf("op" to "requestLocationUpdates"))
            trySend(LocationResult.Failure("Failed to start tracking: ${t.summary()}", t))
            close()
            return@callbackFlow
        }

        // Cleanup when the collector cancels — each Flow removes its own callback.
        awaitClose { client.removeLocationUpdates(callback) }
    }

    // No-op at the provider level: each callbackFlow tears itself down via awaitClose when the
    // collecting coroutine is cancelled. A consumer stops by cancelling that collection.
    override fun stopTracking() = Unit

    // --- internals ---

    // "ExceptionType: message" (or just the type when there is no message) — a richer diagnostic
    // than a bare null message, so the Failure reason a consumer logs is triageable.
    private fun Throwable.summary(): String =
        (this::class.simpleName ?: "Throwable") + (message?.let { ": $it" } ?: "")

    private fun isLocationServiceEnabled(): Boolean {
        val lm = context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager ?: return false
        return try {
            LocationManagerCompat.isLocationEnabled(lm)
        } catch (t: Throwable) {
            crashReporter.report(t, mapOf("op" to "isLocationServiceEnabled"))
            false
        }
    }

    // Synchronous, main-safe self-permission check (same pattern as the permission module's
    // isPreciseLocationGranted). Lets onLocationAvailability detect a mid-stream revocation.
    private fun hasFineLocationPermission(): Boolean = try {
        ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED
    } catch (t: Throwable) {
        crashReporter.report(t, mapOf("op" to "hasFineLocationPermission"))
        false
    }

    private fun isPlayServicesAvailable(): Boolean = try {
        GoogleApiAvailability.getInstance()
            .isGooglePlayServicesAvailable(context) == ConnectionResult.SUCCESS
    } catch (t: Throwable) {
        crashReporter.report(t, mapOf("op" to "isPlayServicesAvailable"))
        false
    }

    /**
     * Returns `true` if location settings are satisfied (possibly after the user accepted the
     * system GPS dialog), `false` if the service is off and couldn't be enabled. Mirrors
     * geolocator's settings flow.
     */
    private suspend fun checkAndResolveSettings(config: TrackingConfig): Boolean {
        val request = LocationSettingsRequest.Builder()
            .addLocationRequest(
                LocationRequest.Builder(config.priority.toGmsPriority(), config.intervalMs).build(),
            )
            .build()
        return try {
            settingsClient.checkLocationSettings(request).await()
            true
        } catch (c: CancellationException) {
            throw c
        } catch (e: ResolvableApiException) {
            // GPS off but fixable via the system dialog (must be checked before ApiException —
            // ResolvableApiException is a subclass).
            resolveSettings(e)
        } catch (e: ApiException) {
            if (e.statusCode == LocationSettingsStatusCodes.SETTINGS_CHANGE_UNAVAILABLE) {
                // Settings can't be changed via dialog (e.g. forced by policy) — try the request
                // anyway; the location call itself will surface the real outcome (geolocator pattern).
                true
            } else {
                crashReporter.report(e, mapOf("op" to "checkLocationSettings"))
                false
            }
        } catch (t: Throwable) {
            crashReporter.report(t, mapOf("op" to "checkLocationSettings"))
            false
        }
    }

    // Main-confined: a consumer may call getCurrentLocation/trackLocation from a non-main dispatcher
    // (e.g. background IoT collection / a CoroutineWorker, which defaults to Dispatchers.Default).
    // The `pendingSettingsResolution` slot and `launcher.launch()` are touched here on the caller's
    // thread but read/resumed on the main thread by onSettingsResolution() and detach() — so without
    // confinement an off-main caller races the slot (stale-read hang) and calls the (non-thread-safe)
    // ActivityResultLauncher off-main. `.immediate` is a no-op when already on Main (the common case).
    // (invokeOnCancellation may still fire off-main on cross-thread cancellation; it only does an
    // identity-guarded null-write that detach()/onSettingsResolution re-guard — benign.)
    private suspend fun resolveSettings(exception: ResolvableApiException): Boolean =
        withContext(Dispatchers.Main.immediate) {
            val launcher = settingsLauncher ?: return@withContext false // no Activity → can't show dialog
            if (pendingSettingsResolution != null) return@withContext false // another dialog in flight
            suspendCancellableCoroutine { cont ->
                pendingSettingsResolution = cont
                // Only clear OUR slot — never a continuation a later caller may have installed.
                cont.invokeOnCancellation {
                    if (pendingSettingsResolution === cont) pendingSettingsResolution = null
                }
                try {
                    launcher.launch(IntentSenderRequest.Builder(exception.resolution).build())
                } catch (t: Throwable) {
                    if (pendingSettingsResolution === cont) pendingSettingsResolution = null
                    crashReporter.report(t, mapOf("op" to "settings resolution launch"))
                    if (cont.isActive) cont.resume(false)
                }
            }
        }
}
