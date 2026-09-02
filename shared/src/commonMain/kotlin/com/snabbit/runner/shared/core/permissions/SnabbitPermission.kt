package com.snabbit.runner.shared.core.permissions

/**
 * All permission types the Snabbit app deals with, as a closed set.
 *
 * Three families:
 *  - **Runtime** — granted via the OS permission dialog (handled by the Grant library).
 *  - **Strict** — require a Settings screen, not a runtime dialog (custom handlers).
 *  - **Informational** — read-only checks (no request possible).
 *
 * Adding a member here forces every `when` over [SnabbitPermission] to be updated,
 * which is intentional: routing/mapping must stay exhaustive.
 */
sealed interface SnabbitPermission {
    // --- Runtime (Grant) ---
    data object LocationFine : SnabbitPermission
    data object LocationCoarse : SnabbitPermission
    data object LocationBackground : SnabbitPermission
    data object Camera : SnabbitPermission
    data object Microphone : SnabbitPermission
    data object Contacts : SnabbitPermission
    data object Notifications : SnabbitPermission

    /**
     * Schedule exact alarms (`SCHEDULE_EXACT_ALARM`, API 31+). This is a *special-access
     * permission*, not a hardware service: on API 31+ it is granted via a Settings toggle
     * ("Alarms & reminders"), so a denial reports `DENIED_ALWAYS` (Grant reads
     * `AlarmManager.canScheduleExactAlarms()`); below API 31 it is implicitly granted.
     * Do not confuse with [ServiceType] (GPS/camera/mic hardware toggles).
     */
    data object ExactAlarm : SnabbitPermission

    /**
     * Photo-library read access.
     *
     * NOTE: the app strips `READ_MEDIA_IMAGES`/`READ_MEDIA_VIDEO` from the merged manifest
     * (`tools:node="remove"`); `READ_MEDIA_VISUAL_USER_SELECTED` is not declared either. Grant
     * resolves this per API level:
     *  - API 33+ (Android 13+): needs `READ_MEDIA_IMAGES` (+ user-selected on 34+) — all absent,
     *    so Grant shows no dialog and the request can't be granted until those entries are restored.
     *  - API <= 32: falls back to `READ_EXTERNAL_STORAGE`, which IS declared (maxSdkVersion=32),
     *    so the request works normally there.
     */
    data object Photos : SnabbitPermission

    /**
     * Legacy shared-storage read access. Resolves the same way as [Photos]: `READ_MEDIA_IMAGES`/
     * `READ_MEDIA_VIDEO` on API 33+ (stripped from the manifest, so a no-op there) or
     * `READ_EXTERNAL_STORAGE` on API <= 32 (declared, so it works).
     */
    data object Storage : SnabbitPermission

    // --- Strict (Settings intents — custom handlers) ---
    data object Overlay : SnabbitPermission
    data object BatteryOptimization : SnabbitPermission
    data object AccessibilityService : SnabbitPermission

    // --- Informational (read-only) ---
    data object AdminPolicy : SnabbitPermission
}
