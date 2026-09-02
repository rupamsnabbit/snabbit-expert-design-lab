package com.snabbit.runner.shared.core.location.di

import com.snabbit.runner.shared.core.location.AppleLocationProvider
import com.snabbit.runner.shared.core.location.LocationProvider
import org.koin.core.module.Module
import org.koin.dsl.module

/**
 * iOS wiring — stub provider until iOS support is built. No attach handle (no GPS dialog).
 *
 * Gating asymmetry (intentional, documented): unlike Android, this binds the raw provider WITHOUT
 * the [com.snabbit.runner.shared.core.location.LocationServiceWrapper] permission gate — there is
 * no iOS `PermissionManager` binding to gate against yet. When the real `CLLocationManager` impl
 * lands, wrap it here as `LocationServiceWrapper(provider, <iOS PermissionManager>)` so the common
 * contract ("no provider call without a granted permission") holds on iOS too. Until then, gating
 * on iOS is the provider's own responsibility (the stub grants nothing — every call is a safe
 * Failure), so the asymmetry is harmless today.
 */
actual fun locationModule(): Module = module {
    single<LocationProvider> { AppleLocationProvider() }
}
