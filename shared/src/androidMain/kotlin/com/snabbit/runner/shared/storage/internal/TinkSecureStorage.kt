package com.snabbit.runner.shared.storage.internal

import com.snabbit.runner.shared.storage.SecureStorage
import com.snabbit.runner.shared.storage.StorageEvent

import android.util.Base64
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import com.google.crypto.tink.Aead
import com.snabbit.runner.shared.core.CrashReporter
import com.snabbit.runner.shared.core.Logger
import kotlinx.coroutines.flow.first
import java.security.GeneralSecurityException
import java.util.concurrent.ConcurrentHashMap

/**
 * [SecureStorage] backed by Tink AES-256-GCM + DataStore Preferences.
 *
 * Write path: plaintext → Tink AEAD encrypt (key name as associated data)
 *   → Base64 → DataStore.
 * Read path: DataStore → Base64 decode → Tink AEAD decrypt.
 *
 * Per-entry associated data = the storage key name, preventing swap
 * attacks where ciphertext for key A is moved to slot B.
 *
 * Exception policy (never crashes the app):
 *  - [GeneralSecurityException] / [IllegalArgumentException] on read →
 *    undecryptable/corrupt payload → return null and **retain** the
 *    ciphertext. A decrypt failure can be transient (e.g. Keystore not yet
 *    ready, or a key still recovering), so deleting the entry would turn a
 *    recoverable secret into permanent data loss. The corruption is logged +
 *    reported once per key (see [corruptionReported]) to avoid telemetry
 *    spam from repeated reads.
 *  - Any other read exception → log [StorageEvent.STORAGE_READ_FAILED],
 *    return null.
 *  - Write failure → log [StorageEvent.STORAGE_WRITE_FAILED], report, and
 *    return `false` so callers can detect a non-persisted value.
 */
internal class TinkSecureStorage(
    private val dataStore: DataStore<Preferences>,
    private val keyManager: KeyManager,
    private val logger: Logger,
    private val crashReporter: CrashReporter,
) : SecureStorage {

    /**
     * Keys whose ciphertext has already been reported as corrupt this
     * process, so a hot read loop over a bad entry reports once, not on every
     * call. Cleared for a key when it is read successfully, overwritten, or
     * removed (so a fresh value is eligible to report again if it later
     * corrupts).
     */
    private val corruptionReported = ConcurrentHashMap.newKeySet<String>()

    // ── internal encrypt / decrypt used by every typed accessor ──

    private suspend fun decryptRaw(key: String): String? = try {
        val encoded = dataStore.data.first()[stringPreferencesKey(key)] ?: return null
        val aead = getAeadOrReport("read", key) ?: return null
        val ciphertext = Base64.decode(encoded, Base64.NO_WRAP)
        val plaintext = aead.decrypt(ciphertext, key.toByteArray(Charsets.UTF_8))
        // Decrypt succeeded — if this key was previously flagged corrupt (e.g. a
        // transient Keystore fault that has since recovered), clear the flag so a
        // genuine future corruption of a new value is reported again.
        corruptionReported.remove(key)
        String(plaintext, Charsets.UTF_8)
    } catch (e: GeneralSecurityException) {
        reportCorruptionOnce(key, e, "decrypt")
        null
    } catch (e: IllegalArgumentException) {
        reportCorruptionOnce(key, e, "bad Base64")
        null
    } catch (e: Exception) {
        logger.e(TAG, "${StorageEvent.STORAGE_READ_FAILED}: key=$key", e)
        crashReporter.report(e, mapOf("op" to "secureStorage.read", "key" to key))
        null
    }

    /** @return true if the ciphertext was persisted. */
    private suspend fun encryptRaw(key: String, plaintext: String): Boolean = try {
        val aead = getAeadOrReport("write", key) ?: return false
        val ciphertext = aead.encrypt(
            plaintext.toByteArray(Charsets.UTF_8),
            key.toByteArray(Charsets.UTF_8),
        )
        val encoded = Base64.encodeToString(ciphertext, Base64.NO_WRAP)
        dataStore.edit { it[stringPreferencesKey(key)] = encoded }
        corruptionReported.remove(key)
        true
    } catch (e: Exception) {
        logger.e(TAG, "${StorageEvent.STORAGE_WRITE_FAILED}: key=$key", e)
        crashReporter.report(e, mapOf("op" to "secureStorage.write", "key" to key))
        false
    }

    /** Resolves the AEAD, reporting a keystore error if it is unavailable. */
    private suspend fun getAeadOrReport(op: String, key: String): Aead? =
        keyManager.getOrCreateAead().also {
            if (it == null) {
                logger.e(TAG, "${StorageEvent.STORAGE_KEYSTORE_ERROR}: AEAD unavailable for $op, key=$key")
                crashReporter.report(
                    IllegalStateException("AEAD unavailable for $op"),
                    mapOf("op" to "secureStorage.$op", "key" to key),
                )
            }
        }

    // Decrypts [key] then parses via [parse]. A present-but-unparseable value
    // means a different type was stored under this key: emit
    // STORAGE_TYPE_MISMATCH so it's distinguishable from an absent key.
    private suspend fun <T> decryptTyped(key: String, parse: (String) -> T?): T? {
        val raw = decryptRaw(key) ?: return null
        return parse(raw) ?: run {
            logger.e(TAG, "${StorageEvent.STORAGE_TYPE_MISMATCH}: key=$key")
            null
        }
    }

    private fun reportCorruptionOnce(key: String, e: Exception, detail: String) {
        if (corruptionReported.add(key)) {
            logger.e(
                TAG,
                "${StorageEvent.STORAGE_CORRUPTED_PAYLOAD}: $detail, key=$key (ciphertext retained)",
                e,
            )
            crashReporter.report(
                e,
                mapOf("op" to "secureStorage.read", "key" to key, "detail" to detail),
            )
        }
    }

    // ── typed accessors ──

    override suspend fun getString(key: String): String? = decryptRaw(key)

    override suspend fun putString(key: String, value: String) = encryptRaw(key, value)

    override suspend fun getInt(key: String): Int? = decryptTyped(key) { it.toIntOrNull() }

    override suspend fun putInt(key: String, value: Int) = encryptRaw(key, value.toString())

    override suspend fun getLong(key: String): Long? = decryptTyped(key) { it.toLongOrNull() }

    override suspend fun putLong(key: String, value: Long) = encryptRaw(key, value.toString())

    override suspend fun getBool(key: String): Boolean? = decryptTyped(key) { it.toBooleanStrictOrNull() }

    override suspend fun putBool(key: String, value: Boolean) = encryptRaw(key, value.toString())

    override suspend fun getDouble(key: String): Double? = decryptTyped(key) { it.toDoubleOrNull() }

    override suspend fun putDouble(key: String, value: Double) = encryptRaw(key, value.toString())

    override suspend fun remove(key: String): Boolean = try {
        dataStore.edit { it.remove(stringPreferencesKey(key)) }
        corruptionReported.remove(key)
        true
    } catch (e: Exception) {
        logger.e(TAG, "${StorageEvent.STORAGE_WRITE_FAILED}: remove key=$key", e)
        crashReporter.report(e, mapOf("op" to "secureStorage.remove", "key" to key))
        false
    }

    override suspend fun clear(): Boolean = try {
        dataStore.edit { it.clear() }
        corruptionReported.clear()
        true
    } catch (e: Exception) {
        logger.e(TAG, "${StorageEvent.STORAGE_WRITE_FAILED}: clear", e)
        crashReporter.report(e, mapOf("op" to "secureStorage.clear"))
        false
    }

    internal companion object {
        const val TAG = "TinkSecureStorage"
        const val DATASTORE_FILE = "snabbit_secure_storage.preferences_pb"
    }
}
