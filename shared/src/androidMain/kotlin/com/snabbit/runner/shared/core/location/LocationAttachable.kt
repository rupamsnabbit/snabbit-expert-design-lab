package com.snabbit.runner.shared.core.location

import androidx.activity.ComponentActivity

/**
 * App-visible handle to attach the current [ComponentActivity] to the location system — the only
 * surface the host app touches to make the system "turn on location" dialog work. Mirrors the
 * permission module's `ActivityAttachable`.
 *
 * Must be called from `onCreate` (before the Activity is STARTED) because it registers an
 * `ActivityResultLauncher` (the GPS-settings resolution). Re-attach on every Activity instance
 * (configuration change / process death): the Koin singleton survives but its launcher is bound
 * to the destroyed Activity.
 */
interface LocationAttachable {
    /** Bind the GPS-settings-resolution launcher to the given (re)created Activity. */
    fun attachActivity(activity: ComponentActivity)

    /** Drop the current Activity reference and unregister the launcher (call from `onDestroy`). */
    fun detach()
}
