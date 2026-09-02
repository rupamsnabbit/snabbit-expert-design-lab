package com.snabbit.runner.shared.core.permissions.internal

import com.snabbit.runner.shared.core.permissions.PermissionStatus
import com.snabbit.runner.shared.core.permissions.SnabbitPermission
import dev.brewkits.grant.GrantPermission
import dev.brewkits.grant.GrantStatus
import dev.brewkits.grant.GrantManager
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow

/**
 * Shared runtime-permission logic, expressed once over Grant's multiplatform [GrantManager].
 *
 * Handles only the runtime permissions Grant knows about (those with a non-null
 * [toGrantOrNull]); strict/informational permissions are routed elsewhere by the
 * platform [com.snabbit.runner.shared.core.permissions.PermissionManager] before reaching this delegate.
 *
 * This layer is platform-agnostic and Grant-status-faithful. The Android-specific
 * `DENIED` → `DENIED_ALWAYS` refinement (which needs an Activity + rationale check) is
 * applied by the Android manager on top of the values returned here.
 *
 * Rationale ownership: neither this module nor Grant shows any rationale UI. The module only
 * *computes* whether one is warranted (`PermissionManager.shouldShowRationale`, backed by
 * `shouldShowRequestPermissionRationale`); the **caller** decides whether/how to render it
 * before calling `request`.
 *
 * @param apiLevel current OS API level; injected so the mapping is testable without a device.
 */
internal class GrantRuntimeDelegate(
    private val grantManager: GrantManager,
    private val apiLevel: () -> Int,
) {

    suspend fun check(permission: SnabbitPermission): PermissionStatus {
        val grant = resolveGrant(permission) ?: return PermissionStatus.NOT_AVAILABLE
        return grantManager.checkStatus(grant).toPermissionStatus(permission)
    }

    suspend fun request(permission: SnabbitPermission): PermissionStatus {
        val grant = resolveGrant(permission) ?: return PermissionStatus.NOT_AVAILABLE
        return grantManager.request(grant).toPermissionStatus(permission)
    }

    /**
     * Batched request — all mappable permissions go to Grant's `request(List)` in one call
     * (Android sequences the dialogs), matching the app's current `permission_handler` UX.
     * Emits one `(permission, status)` per input permission, **in input order**. Permissions
     * unavailable at this API level emit [PermissionStatus.NOT_AVAILABLE] without a dialog.
     */
    fun requestMultiple(
        permissions: List<SnabbitPermission>,
    ): Flow<Pair<SnabbitPermission, PermissionStatus>> = flow {
        val pairs: List<Pair<SnabbitPermission, GrantPermission?>> =
            permissions.map { it to resolveGrant(it) }
        val grants: List<GrantPermission> = pairs.mapNotNull { it.second }

        val results: Map<GrantPermission, GrantStatus> =
            if (grants.isEmpty()) emptyMap() else grantManager.request(grants)

        for ((permission, grant) in pairs) {
            val status = when {
                grant == null -> PermissionStatus.NOT_AVAILABLE
                else -> results[grant]?.toPermissionStatus(permission) ?: PermissionStatus.DENIED
            }
            emit(permission to status)
        }
    }

    /** The Grant permission to use, or `null` if not a runtime permission or not available here. */
    private fun resolveGrant(permission: SnabbitPermission): GrantPermission? {
        if (apiLevel() < permission.minApiLevel()) return null
        return permission.toGrantOrNull()
    }
}
