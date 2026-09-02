package com.snabbit.runner.shared.features.kavach.shield.domain

import com.snabbit.runner.shared.core.permissions.PermissionManager
import com.snabbit.runner.shared.core.permissions.PermissionStatus
import com.snabbit.runner.shared.core.permissions.SnabbitPermission

/** Which permissions a shield flow needs. */
enum class KavachPermissionContext { MicOnly, MicAndLocation }

sealed interface KavachPermissionResult {
    /** All required permissions granted — proceed. */
    data object Granted : KavachPermissionResult
    /** Denied this pass — soft-blocked; the runner can retry. */
    data object Denied : KavachPermissionResult
    /** Permanently denied — settings were opened; the runner must grant there. */
    data object NeedsSettings : KavachPermissionResult
}

/**
 * App-driven permission gate for Kavach (2f), over the shipped [PermissionManager] seam (no new
 * host bridge). Re-check-first (skip the OS dialog when already granted); request SEQUENTIALLY so
 * background location is never batched with the foreground grant; aggregate → all granted =
 * [KavachPermissionResult.Granted]; any permanently-denied opens settings and returns
 * [KavachPermissionResult.NeedsSettings]; otherwise [KavachPermissionResult.Denied]. The UI dialog +
 * ON_RESUME re-check are the device-verify layer that consumes this (deferred).
 */
class KavachPermissionGate(private val permissions: PermissionManager) {

    suspend fun ensure(context: KavachPermissionContext): KavachPermissionResult {
        var deniedAlways = false
        var denied = false
        for (perm in requiredFor(context)) {
            // Re-check first — request (needs an Activity) only if not already granted.
            val status = permissions.check(perm).takeIf { it == PermissionStatus.GRANTED } ?: permissions.request(perm)
            when (status) {
                // NOT_AVAILABLE (iOS / no Grant runtime) is non-blocking — skip the gate, don't brick.
                PermissionStatus.GRANTED, PermissionStatus.NOT_AVAILABLE -> {}
                PermissionStatus.DENIED_ALWAYS -> deniedAlways = true
                PermissionStatus.DENIED -> denied = true
            }
        }
        return when {
            !deniedAlways && !denied -> KavachPermissionResult.Granted
            deniedAlways -> { permissions.openSettings(); KavachPermissionResult.NeedsSettings }
            else -> KavachPermissionResult.Denied
        }
    }

    /** Check-only (no OS prompt) — are all required permissions currently granted? Drives the ON_RESUME recheck. */
    suspend fun isGranted(context: KavachPermissionContext): Boolean =
        requiredFor(context).all {
            val status = permissions.check(it)
            status == PermissionStatus.GRANTED || status == PermissionStatus.NOT_AVAILABLE
        }

    /** Re-open the app's OS settings — the NeedsSettings dialog's primary action. */
    fun openSettings() = permissions.openSettings()

    private fun requiredFor(context: KavachPermissionContext): List<SnabbitPermission> = when (context) {
        KavachPermissionContext.MicOnly -> listOf(SnabbitPermission.Microphone)
        KavachPermissionContext.MicAndLocation ->
            listOf(SnabbitPermission.Microphone, SnabbitPermission.LocationFine, SnabbitPermission.LocationBackground)
    }
}
