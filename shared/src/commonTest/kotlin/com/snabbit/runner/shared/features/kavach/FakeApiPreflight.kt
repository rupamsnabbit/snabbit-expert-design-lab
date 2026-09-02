package com.snabbit.runner.shared.features.kavach

import com.snabbit.runner.shared.core.connectivity.ConnectivityStatus
import com.snabbit.runner.shared.core.connectivity.NetworkMonitor
import com.snabbit.runner.shared.core.storage.StoreManager
import com.snabbit.runner.shared.features.kavach.shared.data.ApiPreflight
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/** StoreManager stub for [ApiPreflight] — only the token slot is exercised. */
class FakeTokenStoreManager(var token: String? = "test-token") : StoreManager {
    override suspend fun hydrateAll() {}
    override fun tokenSnapshot(): String? = token
    override suspend fun awaitToken(): String? = token
    override suspend fun pushToken(token: String?) { this.token = token }
    override suspend fun clearToken() { token = null }
}

/** NetworkMonitor stub — online unless a test says otherwise. */
class FakeNetworkMonitor(initial: ConnectivityStatus = ConnectivityStatus.Online) : NetworkMonitor {
    private val _status = MutableStateFlow(initial)
    override val status: StateFlow<ConnectivityStatus> = _status
    fun set(value: ConnectivityStatus) { _status.value = value }
}

/**
 * Pre-flight that lets calls through — the default for API tests that aren't testing the gate.
 * Pass a null/blank token or an offline status to exercise the skip paths.
 */
fun testPreflight(
    token: String? = "test-token",
    status: ConnectivityStatus = ConnectivityStatus.Online,
    analytics: FakeAnalyticsTracker = FakeAnalyticsTracker(),
) = ApiPreflight(FakeTokenStoreManager(token), analytics, FakeNetworkMonitor(status))
