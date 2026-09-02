package com.snabbit.runner.shared.core.permissions

import androidx.activity.ComponentActivity

/**
 * App-visible handle to attach the current [ComponentActivity] to the permission system.
 *
 * The concrete [PermissionManager] is `internal`; this is the only surface the host app
 * touches to wire up the Activity. Must be called from `onCreate` (before the Activity is
 * STARTED) because it registers `ActivityResultLauncher`s (Grant's permission launcher and
 * the Settings-screen launcher used by strict permissions).
 *
 * Re-attach on every Activity instance (configuration change / process death): the Koin
 * singletons survive but their launchers are bound to the destroyed Activity.
 *
 * Until an Activity is attached, [PermissionManager.request]/`requestMultiple`/`shouldShowRationale`
 * can't show UI and degrade to DENIED/false (see the PermissionManager usage contract). Reads
 * ([PermissionManager.check] etc.) work without an attached Activity, so background consumers
 * (e.g. the IoT collector while the app is killed) don't need to attach.
 */
interface ActivityAttachable {
    /** Bind the launchers + activity reference for the given (re)created Activity. */
    fun attachActivity(activity: ComponentActivity)

    /** Drop the current Activity reference (call from `onDestroy`). */
    fun detach()
}
