package com.snabbit.runner.shared.core.permissions

/**
 * Snapshot of device-administration / MDM state, used to explain to the user when an
 * enterprise policy (not the app) is blocking a permission or feature.
 *
 * Read-only: there is no "request" for this — it is informational only.
 */
data class AdminPolicyInfo(
    /** Package names of active device-admin components (may be empty). */
    val adminPackages: List<String>,
    /** Location-related policy is being controlled by an admin. */
    val isLocationPolicyControlled: Boolean,
    /**
     * False when the admin state could NOT be determined (an OS API threw). Distinct from a
     * known "no policy" ([NONE]) — callers must not treat an unknown result as "all clear".
     */
    val isKnown: Boolean = true,
) {
    /** A device admin / device owner / profile owner is active. Derived from [adminPackages]. */
    val isDeviceManaged: Boolean get() = adminPackages.isNotEmpty()

    companion object {
        /** Known state: no admin policy (also the iOS stub default). */
        val NONE = AdminPolicyInfo(adminPackages = emptyList(), isLocationPolicyControlled = false)

        /** Detection failed — explicitly NOT "all clear" ([isKnown] is false). */
        val UNKNOWN = AdminPolicyInfo(
            adminPackages = emptyList(),
            isLocationPolicyControlled = false,
            isKnown = false,
        )
    }
}
