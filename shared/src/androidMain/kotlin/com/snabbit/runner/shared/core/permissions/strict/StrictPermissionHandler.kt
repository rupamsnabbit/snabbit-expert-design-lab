package com.snabbit.runner.shared.core.permissions.strict

import android.content.Intent

/**
 * Strategy for a "strict" permission — one that is toggled on a Settings screen rather than
 * via a runtime dialog (overlay, battery optimization, accessibility).
 *
 * The manager checks [isGranted], and if not granted launches [settingsIntent] and re-checks
 * [isGranted] when the user returns.
 */
internal interface StrictPermissionHandler {
    /** Whether the permission is currently granted. */
    fun isGranted(): Boolean

    /** The Settings intent to send the user to, or `null` if not resolvable on this device. */
    fun settingsIntent(): Intent?
}
