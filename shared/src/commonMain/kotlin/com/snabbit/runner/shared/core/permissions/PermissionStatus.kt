package com.snabbit.runner.shared.core.permissions

/**
 * Unified permission status exposed to callers.
 *
 * This is intentionally a 4-value set. Grant's richer [dev.brewkits.grant.GrantStatus]
 * (6 values incl. PARTIAL_GRANTED/NOT_DETERMINED/BUSY) is collapsed onto these by the
 * internal mapping layer — callers only ever reason about these four.
 */
enum class PermissionStatus {
    /** Granted (incl. Android 14+ "partial"/limited access, which is usable). */
    GRANTED,

    /** Denied, but the system dialog can still be shown again. Show rationale, then re-request. */
    DENIED,

    /** Permanently denied ("don't ask again"). The only path forward is [PermissionManager.openSettings]. */
    DENIED_ALWAYS,

    /** The permission does not exist on this device/OS level (e.g. background location < API 29). */
    NOT_AVAILABLE,
}
