package com.snabbit.runner.shared.core.storage

/**
 * HashMap-backed [EncryptedStore] for commonTest. No crypto, no I/O —
 * lets StoreManagerImpl and SnabbitHttpClient be unit-tested on the JVM
 * (and future iOS) without any Android Keystore dependency.
 *
 * Tracks the read call counts tests assert on (e.g. that
 * [StoreManager.hydrateAll] uses a single [getAll] snapshot rather than N
 * [getString] calls).
 *
 * See §11.6.
 */
class InMemoryEncryptedStore : EncryptedStore {
    private val map = mutableMapOf<String, String>()

    var getStringCalls: Int = 0
        private set
    var getAllCalls: Int = 0
        private set

    override suspend fun getString(key: String): String? {
        getStringCalls++
        return map[key]
    }

    override suspend fun putString(key: String, value: String) {
        map[key] = value
    }

    override suspend fun delete(key: String) {
        map.remove(key)
    }

    override suspend fun getAll(keys: Set<String>): Map<String, String> {
        getAllCalls++
        return keys.mapNotNull { k -> map[k]?.let { k to it } }.toMap()
    }
}
