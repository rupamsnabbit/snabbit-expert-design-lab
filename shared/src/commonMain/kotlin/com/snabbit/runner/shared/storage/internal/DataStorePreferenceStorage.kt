package com.snabbit.runner.shared.storage.internal

import com.snabbit.runner.shared.storage.PreferenceStorage
import com.snabbit.runner.shared.storage.StorageEvent

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.doublePreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.MutablePreferences
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import com.snabbit.runner.shared.core.CrashReporter
import com.snabbit.runner.shared.core.Logger
import kotlinx.coroutines.flow.first

/**
 * [PreferenceStorage] backed by Jetpack DataStore Preferences (KMP).
 *
 * DataStore provides atomic read-modify-write, coroutine-native I/O,
 * native support for all primitive types (including Double), and
 * cross-platform support (Android + iOS).
 *
 * Same fail-safe contract as [SecureStorage]: operations never throw,
 * read failures return null, write failures are logged.
 */
internal class DataStorePreferenceStorage(
    private val dataStore: DataStore<Preferences>,
    private val logger: Logger,
    private val crashReporter: CrashReporter,
) : PreferenceStorage {

    // ── String ──

    override suspend fun getString(key: String): String? = readOp(key) {
        it[stringPreferencesKey(key)]
    }

    override suspend fun putString(key: String, value: String) = writeOp(key) {
        it[stringPreferencesKey(key)] = value
    }

    // ── Int ──

    override suspend fun getInt(key: String): Int? = readOp(key) {
        it[intPreferencesKey(key)]
    }

    override suspend fun putInt(key: String, value: Int) = writeOp(key) {
        it[intPreferencesKey(key)] = value
    }

    // ── Long ──

    override suspend fun getLong(key: String): Long? = readOp(key) {
        it[longPreferencesKey(key)]
    }

    override suspend fun putLong(key: String, value: Long) = writeOp(key) {
        it[longPreferencesKey(key)] = value
    }

    // ── Boolean ──

    override suspend fun getBool(key: String): Boolean? = readOp(key) {
        it[booleanPreferencesKey(key)]
    }

    override suspend fun putBool(key: String, value: Boolean) = writeOp(key) {
        it[booleanPreferencesKey(key)] = value
    }

    // ── Double ──

    override suspend fun getDouble(key: String): Double? = readOp(key) {
        it[doublePreferencesKey(key)]
    }

    override suspend fun putDouble(key: String, value: Double) = writeOp(key) {
        it[doublePreferencesKey(key)] = value
    }

    // ── remove / clear ──

    override suspend fun remove(key: String): Boolean = try {
        // DataStore keys are equal by name regardless of value type, so one
        // remove clears whatever type was stored under this key.
        dataStore.edit { it.remove(stringPreferencesKey(key)) }
        true
    } catch (e: Exception) {
        logger.e(TAG, "${StorageEvent.STORAGE_WRITE_FAILED}: remove key=$key", e)
        crashReporter.report(e, mapOf("op" to "preferenceStorage.remove", "key" to key))
        false
    }

    override suspend fun clear(): Boolean = try {
        dataStore.edit { it.clear() }
        true
    } catch (e: Exception) {
        logger.e(TAG, "${StorageEvent.STORAGE_WRITE_FAILED}: clear", e)
        crashReporter.report(e, mapOf("op" to "preferenceStorage.clear"))
        false
    }

    // ── shared helpers ──

    private suspend fun <T> readOp(key: String, block: (Preferences) -> T?): T? = try {
        block(dataStore.data.first())
    } catch (e: Exception) {
        logger.e(TAG, "${StorageEvent.STORAGE_READ_FAILED}: key=$key", e)
        crashReporter.report(e, mapOf("op" to "preferenceStorage.read", "key" to key))
        null
    }

    private suspend fun writeOp(key: String, block: (MutablePreferences) -> Unit): Boolean = try {
        dataStore.edit { block(it) }
        true
    } catch (e: Exception) {
        logger.e(TAG, "${StorageEvent.STORAGE_WRITE_FAILED}: key=$key", e)
        crashReporter.report(e, mapOf("op" to "preferenceStorage.write", "key" to key))
        false
    }

    internal companion object {
        const val TAG = "DataStorePrefStorage"
        const val DATASTORE_FILE = "snabbit_preference_storage.preferences_pb"
    }
}
