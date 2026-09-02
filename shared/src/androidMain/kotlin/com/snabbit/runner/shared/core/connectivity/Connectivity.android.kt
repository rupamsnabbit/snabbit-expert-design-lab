package com.snabbit.runner.shared.core.connectivity

import android.app.Application
import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

actual class ConnectivityFactory(private val app: Application) {
    actual fun create(): Connectivity = AndroidConnectivity(app)
}

/** `registerDefaultNetworkCallback` (API 24+; shared minSdk 26): onAvailable→true, onLost→false. */
private class AndroidConnectivity(app: Application) : Connectivity {
    private val _online = MutableStateFlow(false)
    override val online: StateFlow<Boolean> = _online.asStateFlow()

    init {
        val cm = app.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        cm.registerDefaultNetworkCallback(object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) { _online.value = true }
            override fun onLost(network: Network) { _online.value = false }
        })
    }
}
