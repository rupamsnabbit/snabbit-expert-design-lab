package com.snabbit.runner.shared.core.permissions.internal

import android.content.Context
import android.content.pm.PackageManager
import android.location.LocationManager
import androidx.core.location.LocationManagerCompat
import com.snabbit.runner.shared.core.permissions.ServiceType
import com.snabbit.runner.shared.core.CrashReporter

/**
 * Synchronous hardware/service checks.
 *
 * - GPS: the location master toggle via [LocationManagerCompat.isLocationEnabled] (the same
 *   approach geolocator uses); usable inside fast callbacks, unlike Play Services' async check.
 * - CAMERA / MICROPHONE: hardware presence via `PackageManager` features. The Android 12+
 *   *privacy toggle* state is not readable by ordinary apps (needs a privileged permission),
 *   so this reports hardware availability — consistent with Grant's `CAMERA_HARDWARE` model.
 */
internal class AndroidServiceChecker(
    private val context: Context,
    private val crashReporter: CrashReporter,
) {

    fun isEnabled(service: ServiceType): Boolean = try {
        when (service) {
            ServiceType.GPS -> {
                val lm = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
                LocationManagerCompat.isLocationEnabled(lm)
            }
            ServiceType.CAMERA ->
                context.packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_ANY)
            ServiceType.MICROPHONE ->
                context.packageManager.hasSystemFeature(PackageManager.FEATURE_MICROPHONE)
        }
    } catch (t: Throwable) {
        // A wrong "service off" can wedge location-dependent flows — leave a breadcrumb.
        crashReporter.report(t, mapOf("op" to "isServiceEnabled:$service"))
        false
    }
}
