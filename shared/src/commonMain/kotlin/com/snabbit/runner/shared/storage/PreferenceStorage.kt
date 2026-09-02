package com.snabbit.runner.shared.storage

/**
 * Unencrypted key-value storage for non-sensitive application data
 * (feature flags, app settings, onboarding state, cached configuration).
 * Backed by Jetpack DataStore Preferences (KMP) on Android and iOS.
 *
 * Same fail-safe contract as [SecureStorage]: never throws, reads return
 * null on a miss/failure, and writes return a success flag — `true` when
 * persisted, `false` when the operation failed (already logged via
 * [StorageEvent] + reported).
 */
interface PreferenceStorage {

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
