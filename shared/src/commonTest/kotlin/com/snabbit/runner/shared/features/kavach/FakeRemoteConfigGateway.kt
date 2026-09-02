package com.snabbit.runner.shared.features.kavach

import com.snabbit.runner.shared.core.config.RemoteConfigGateway

/** Map-backed fake — returns a set value for a key, else the caller's default. */
class FakeRemoteConfigGateway : RemoteConfigGateway {
    val booleans = mutableMapOf<String, Boolean>()
    val ints = mutableMapOf<String, Int>()
    val doubles = mutableMapOf<String, Double>()
    val strings = mutableMapOf<String, String>()
    val stringLists = mutableMapOf<String, List<String>>()
    var fetchAndActivateCalls = 0
    var fetchAndActivateResult = false

    override suspend fun getBoolean(key: String, default: Boolean) = booleans[key] ?: default
    override suspend fun getInt(key: String, default: Int) = ints[key] ?: default
    override suspend fun getDouble(key: String, default: Double) = doubles[key] ?: default
    override suspend fun getString(key: String, default: String) = strings[key] ?: default
    override suspend fun getStringList(key: String, default: List<String>) = stringLists[key] ?: default
    override suspend fun fetchAndActivate(): Boolean { fetchAndActivateCalls++; return fetchAndActivateResult }
}
