package com.snabbit.runner.shared.core.permissions.fakes

import com.snabbit.runner.shared.core.permissions.AdminPolicyInfo
import com.snabbit.runner.shared.core.permissions.PermissionManager
import com.snabbit.runner.shared.core.permissions.PermissionStatus
import com.snabbit.runner.shared.core.permissions.ServiceType
import com.snabbit.runner.shared.core.permissions.SnabbitPermission
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow

/**
 * Programmable [PermissionManager] double for consumer-module tests (e.g. the Location
 * module's wrapper). Defaults are deliberately permissive-where-safe and overridable.
 */
class FakePermissionManager(
    val statuses: MutableMap<SnabbitPermission, PermissionStatus> = mutableMapOf(),
    var defaultStatus: PermissionStatus = PermissionStatus.DENIED,
    var preciseLocation: Boolean = true,
    val servicesEnabled: MutableMap<ServiceType, Boolean> = mutableMapOf(),
    var adminPolicy: AdminPolicyInfo = AdminPolicyInfo.NONE,
    var rationale: Boolean = false,
) : PermissionManager {

    override suspend fun check(permission: SnabbitPermission): PermissionStatus =
        statuses[permission] ?: defaultStatus

    override suspend fun request(permission: SnabbitPermission): PermissionStatus =
        statuses[permission] ?: defaultStatus

    override fun requestMultiple(
        permissions: List<SnabbitPermission>,
    ): Flow<Pair<SnabbitPermission, PermissionStatus>> = flow {
        permissions.forEach { emit(it to (statuses[it] ?: defaultStatus)) }
    }

    override fun shouldShowRationale(permission: SnabbitPermission): Boolean = rationale

    override fun isPreciseLocationGranted(): Boolean = preciseLocation

    var openSettingsCalls = 0
        private set

    override fun openSettings() { openSettingsCalls++ }

    override fun isServiceEnabled(service: ServiceType): Boolean = servicesEnabled[service] ?: true

    override fun checkAdminPolicy(): AdminPolicyInfo = adminPolicy
}
