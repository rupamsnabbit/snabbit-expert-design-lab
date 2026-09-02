package com.snabbit.runner.shared.core.storage

/**
 * Generic encrypted key-value I/O. No domain knowledge — just get/put/delete
 * strings. Lives in commonMain so it's platform-free; production
 * implementations live in androidMain (Tink + DataStore) and iosMain (Keychain).
 *
 * All operations are suspend because the production backing store is
 * disk-backed and there is no safe way to do disk I/O synchronously without
 * risking ANR. Callers should invoke from a coroutine on an I/O dispatcher.
 *
 * See KMP_NETWORK_MODULE_LLD §11.2.
 */
interface EncryptedStore {
    suspend fun getString(key: String): String?
    suspend fun putString(key: String, value: String)
    suspend fun delete(key: String)

    /**
     * One-shot read of multiple keys. Production implementations take a
     * single snapshot of the underlying store and decrypt only the
     * requested entries — used by [StoreManager.hydrateAll] to avoid N
     * separate disk reads at app start.
     *
     * Keys not present in the store are absent from the returned map.
     */
    suspend fun getAll(keys: Set<String>): Map<String, String>
}
