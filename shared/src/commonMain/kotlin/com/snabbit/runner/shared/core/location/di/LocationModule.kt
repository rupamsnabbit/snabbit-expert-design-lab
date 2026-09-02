package com.snabbit.runner.shared.core.location.di

import org.koin.core.module.Module

/**
 * Koin module exposing [com.snabbit.runner.shared.core.location.LocationProvider].
 *
 * Platform-specific: the Android actual wires the FusedLocationProviderClient wrapper (gated by
 * the permission module) and the GPS-settings-dialog attach handle
 * ([com.snabbit.runner.shared.core.location.LocationAttachable]); the iOS actual provides a stub.
 *
 * Register in the app's `startKoin { modules(permissionsModule(), locationModule(), ...) }`.
 * Depends on a [com.snabbit.runner.shared.core.permissions.PermissionManager] binding (from `permissionsModule()`)
 * and a [com.snabbit.runner.shared.core.CrashReporter] binding (provided by the host app).
 */
expect fun locationModule(): Module
