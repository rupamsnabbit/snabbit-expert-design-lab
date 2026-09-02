package com.snabbit.runner.shared.core.connectivity

import kotlinx.cinterop.ExperimentalForeignApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import platform.Network.nw_path_get_status
import platform.Network.nw_path_monitor_create
import platform.Network.nw_path_monitor_set_queue
import platform.Network.nw_path_monitor_set_update_handler
import platform.Network.nw_path_monitor_start
import platform.Network.nw_path_status_satisfied
import platform.darwin.dispatch_get_global_queue

@OptIn(ExperimentalForeignApi::class)
actual class ConnectivityFactory {
    actual fun create(): Connectivity = IosConnectivity()
}

/** `nw_path_monitor` (Network.framework): satisfied → online. App-lifetime monitor (never cancelled). */
@OptIn(ExperimentalForeignApi::class)
private class IosConnectivity : Connectivity {
    private val _online = MutableStateFlow(false)
    override val online: StateFlow<Boolean> = _online.asStateFlow()

    init {
        val monitor = nw_path_monitor_create()
        nw_path_monitor_set_update_handler(monitor) { path ->
            _online.value = nw_path_get_status(path) == nw_path_status_satisfied
        }
        nw_path_monitor_set_queue(monitor, dispatch_get_global_queue(0, 0u))
        nw_path_monitor_start(monitor)
    }
}
