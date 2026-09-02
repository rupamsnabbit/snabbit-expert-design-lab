package com.snabbit.runner.shared.core.permissions.strict

import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.os.UserManager
import com.snabbit.runner.shared.core.permissions.AdminPolicyInfo
import com.snabbit.runner.shared.core.CrashReporter

/**
 * Read-only device-administration / MDM detection. Used to explain to the user when an
 * enterprise policy (not the app) is restricting a permission. Never throws — returns
 * [AdminPolicyInfo.UNKNOWN] on failure (NOT [AdminPolicyInfo.NONE], which would read as
 * "all clear"), recording a breadcrumb so an MDM-blocked device isn't silently misreported.
 */
internal class AdminPolicyChecker(
    private val context: Context,
    private val crashReporter: CrashReporter,
) {

    fun check(): AdminPolicyInfo = try {
        val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        val admins: List<ComponentName> = dpm.activeAdmins ?: emptyList()
        AdminPolicyInfo(
            adminPackages = admins.map { it.packageName }.distinct(),
            isLocationPolicyControlled = isLocationRestricted(),
        )
    } catch (t: Throwable) {
        crashReporter.report(t, mapOf("op" to "checkAdminPolicy"))
        AdminPolicyInfo.UNKNOWN
    }

    private fun isLocationRestricted(): Boolean = try {
        val um = context.getSystemService(Context.USER_SERVICE) as UserManager
        um.hasUserRestriction(UserManager.DISALLOW_CONFIG_LOCATION) ||
            um.hasUserRestriction(UserManager.DISALLOW_SHARE_LOCATION)
    } catch (t: Throwable) {
        crashReporter.report(t, mapOf("op" to "checkAdminPolicy:isLocationRestricted"))
        false
    }
}
