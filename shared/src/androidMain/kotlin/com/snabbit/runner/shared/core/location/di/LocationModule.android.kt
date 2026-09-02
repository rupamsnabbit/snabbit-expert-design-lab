package com.snabbit.runner.shared.core.location.di

import com.snabbit.runner.shared.core.location.FusedLocationProvider
import com.snabbit.runner.shared.core.location.LocationAttachable
import com.snabbit.runner.shared.core.location.LocationProvider
import com.snabbit.runner.shared.core.location.LocationServiceWrapper
import com.snabbit.runner.shared.core.permissions.PermissionManager
import com.snabbit.runner.shared.core.CrashReporter
import org.koin.android.ext.koin.androidContext
import org.koin.core.module.Module
import org.koin.dsl.module

/**
 * Android wiring. One [FusedLocationProvider] instance backs both the raw provider and
 * [LocationAttachable] (the GPS-dialog launcher handle). The bound [LocationProvider] is the
 * permission-gated [LocationServiceWrapper]. A [CrashReporter] and a [PermissionManager] must be
 * provided by the host (`platformModule` + `permissionsModule()`).
 */
actual fun locationModule(): Module = module {
    single { FusedLocationProvider(androidContext(), get<CrashReporter>()) }
    single<LocationAttachable> { get<FusedLocationProvider>() }
    single<LocationProvider> {
        LocationServiceWrapper(get<FusedLocationProvider>(), get<PermissionManager>())
    }
}
