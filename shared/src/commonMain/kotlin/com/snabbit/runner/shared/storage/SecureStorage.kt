package com.snabbit.runner.shared.storage

/**
 * Encrypted key-value storage for sensitive data (tokens, session IDs,
 * authentication state). Backed by platform crypto on each target:
 * Android → Tink AES-256-GCM + Android Keystore (ciphertext in DataStore);
 * iOS → Keychain Services (hardware-backed, Secure Enclave where available).
 *
 * All operations are suspend (disk-backed) and never throw. Reads return
 * null on a miss or an unrecoverable read; writes return a success flag —
 * `true` when the value was persisted, `false` when the operation failed
 * (already logged via [StorageEvent] + reported). Callers that care about
 * durability (e.g. persisting an auth token) should check the flag rather
 * than assume success.
 *
 * A `SecureStorage` read that hits an undecryptable/corrupt entry returns
 * null and **retains** the ciphertext (a transient crypto fault must not
 * permanently destroy a recoverable secret); it does not delete it.
 */
interface SecureStorage {

    suspend fun getString(key: String): String?
    suspend fun putString(key: String, value: String): Boolean

    suspend fun getInt(key: String): Int?
    suspend fun putInt(key: String, value: Int): Boolean

    suspend fun getLong(key: String): Long?
    suspend fun putLong(key: String, value: Long): Boolean

    suspend fun getBool(key: String): Boolean?
    suspend fun putBool(key: String, value: Boolean): Boolean

    suspend fun getDouble(key: String): Double?
    suspend fun putDouble(key: String, value: Double): Boolean

    /** @return true if the entry is gone after the call (including already-absent). */
    suspend fun remove(key: String): Boolean

    /** @return true if the store is empty after the call. */
    suspend fun clear(): Boolean
}
