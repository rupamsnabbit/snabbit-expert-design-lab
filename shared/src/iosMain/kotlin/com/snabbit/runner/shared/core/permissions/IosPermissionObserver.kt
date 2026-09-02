package com.snabbit.runner.shared.core.permissions

import com.snabbit.runner.shared.core.lifecycle.AppLifecycle
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.emitAll
import kotlinx.coroutines.flow.filter
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.map

/**
 * iOS [PermissionObserver]. iOS (like Android) has no permission grant/revoke callback, so it
 * re-checks on every app foreground via [AppLifecycle] plus an initial emission, deduped with
 * distinctUntilChanged — mirroring `AndroidPermissionObserver`'s ON_RESUME re-check. (Location auth
 * also has a delegate signal, but foreground re-check keeps mic/location/service uniform, matching
 * Android; GPS has no iOS `PROVIDERS_CHANGED` equivalent, so it re-checks on foreground too.)
 */
internal class IosPermissionObserver(
    private val permissions: PermissionManager,
    private val lifecycle: AppLifecycle,
) : PermissionObserver {

    override fun observePermission(permission: SnabbitPermission): Flow<PermissionStatus> =
        reCheckOnForeground { permissions.check(permission) }

    override fun observeService(service: ServiceType): Flow<Boolean> =
        reCheckOnForeground { permissions.isServiceEnabled(service) }

    /** Emit the current value, then re-read on each foreground edge; dedup repeats. */
    private fun <T> reCheckOnForeground(read: suspend () -> T): Flow<T> = flow {
        emit(read())
        emitAll(lifecycle.foreground.filter { it }.map { read() })
    }.distinctUntilChanged()
}
