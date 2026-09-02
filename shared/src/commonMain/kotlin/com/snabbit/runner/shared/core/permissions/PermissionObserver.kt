package com.snabbit.runner.shared.core.permissions

import kotlinx.coroutines.flow.Flow

/**
 * Reactive view of permission / service state (Observer).
 *
 * Android has no system callback for permission grant/revoke, so implementations
 * typically re-check on lifecycle resume; service toggles (e.g. GPS) can be observed
 * via system broadcasts. Consumers use this to react when the user changes something
 * in Settings while the app is open.
 */
interface PermissionObserver {
    /** Emits the current [PermissionStatus] and again whenever it changes. */
    fun observePermission(permission: SnabbitPermission): Flow<PermissionStatus>

    /** Emits the current enabled-state and again whenever the service toggle changes. */
    fun observeService(service: ServiceType): Flow<Boolean>
}
