package com.snabbit.runner.shared.core.permissions.fakes

import dev.brewkits.grant.GrantLauncher
import dev.brewkits.grant.GrantManager
import dev.brewkits.grant.GrantPermission
import dev.brewkits.grant.GrantStatus

/**
 * Test double for Grant's [GrantManager]. Keyed by [GrantPermission.identifier].
 */
class FakeGrantManager(
    private val statuses: MutableMap<String, GrantStatus> = mutableMapOf(),
    private val default: GrantStatus = GrantStatus.NOT_DETERMINED,
    /** When set, every check/request throws this — models an unexpected Grant/OEM failure. */
    var failure: Throwable? = null,
) : GrantManager {

    /** Identifiers passed to any `request(...)` call, in order. */
    val requested = mutableListOf<String>()

    fun setStatus(identifier: String, status: GrantStatus) {
        statuses[identifier] = status
    }

    override suspend fun checkStatus(grant: GrantPermission): GrantStatus {
        failure?.let { throw it }
        return statuses[grant.identifier] ?: default
    }

    override suspend fun request(grant: GrantPermission): GrantStatus {
        failure?.let { throw it }
        requested += grant.identifier
        return statuses[grant.identifier] ?: default
    }

    override suspend fun request(grants: List<GrantPermission>): Map<GrantPermission, GrantStatus> {
        failure?.let { throw it }
        requested += grants.map { it.identifier }
        return grants.associateWith { statuses[it.identifier] ?: default }
    }

    override fun openSettings() = Unit
    override fun setLauncher(launcher: GrantLauncher) = Unit
}
