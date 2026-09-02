package com.snabbit.runner.shared.core.permissions

/**
 * Hardware / OS service toggles — distinct from permissions.
 *
 * A permission can be GRANTED while the underlying service is OFF (e.g. location
 * permission granted but GPS disabled), in which case the feature still won't work.
 */
enum class ServiceType {
    /** Location services master toggle. If off, GPS won't work even with permission granted. */
    GPS,

    /**
     * Whether the device has a camera. Reports hardware presence (PackageManager feature) — the
     * Android 12+ camera *privacy toggle* state is not readable by ordinary apps (see
     * AndroidServiceChecker), so it is NOT reflected here.
     */
    CAMERA,

    /** Whether the device has a microphone. Same caveat as [CAMERA] — hardware presence, not the privacy toggle. */
    MICROPHONE,
}
