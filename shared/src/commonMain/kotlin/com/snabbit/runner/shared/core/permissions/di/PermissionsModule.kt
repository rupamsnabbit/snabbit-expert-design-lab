package com.snabbit.runner.shared.core.permissions.di

import org.koin.core.module.Module

/**
 * Koin module exposing the permission API: [com.snabbit.runner.shared.core.permissions.PermissionManager],
 * [com.snabbit.runner.shared.core.permissions.PermissionObserver], and on Android the
 * [com.snabbit.runner.shared.core.permissions.ActivityAttachable] handle.
 *
 * Platform-specific: the Android actual wires Grant + the strict handlers; the iOS actual provides
 * a stub. Add to the module list in
 * [com.snabbit.runner.shared.core.KmpBootstrap] (`modules(..., permissionsModule(), ...)`).
 *
 * A [com.snabbit.runner.shared.core.CrashReporter] binding is provided by `platformModule`
 * (host-supplied Crashlytics lambda, or a logging no-op) — this module reuses it rather than
 * binding its own, so diagnostics stay unified across the KMP layer.
 */
expect fun permissionsModule(): Module
