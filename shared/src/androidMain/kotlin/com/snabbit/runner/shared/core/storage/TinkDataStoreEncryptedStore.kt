package com.snabbit.runner.shared.core.storage

import android.content.Context
import android.util.Base64
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.google.crypto.tink.Aead
import com.google.crypto.tink.KeyTemplates
import com.google.crypto.tink.RegistryConfiguration
import com.google.crypto.tink.integration.android.AndroidKeysetManager
import com.snabbit.runner.shared.core.CrashReporter
import kotlinx.coroutines.flow.first
import java.io.IOException
import java.security.GeneralSecurityException
import java.security.KeyStore

/**
 * Production [EncryptedStore] for Android (§11.5).
 *
 * Pipeline:
 *   putString → Tink AES-256-GCM encrypt → Base64 → DataStore (disk)
 *   getString → DataStore → Base64 decode → Tink AES-256-GCM decrypt
 *
 *  - Master key lives in Android Keystore (hardware-backed when available).
 *  - Tink AEAD authenticates ciphertext; tamper → decrypt throws → null.
 *  - Per-entry associated data = the key name, preventing swap attacks
 *    where ciphertext for key A is moved to slot B.
 *
 * All methods are suspending; no `runBlocking`. Tink's `AeadConfig.register()`
 * is owned by `SnabbitRunnerApplication.onCreate` — not this class's
 * constructor — because it's an app-lifecycle concern.
 *
 * Exception policy on read:
 *  - [GeneralSecurityException] / [IllegalArgumentException] → returns `null`.
 *    These mean tamper, master-key rotation, or Base64 corruption — all
 *    expected and equivalent to "value is missing".
 *  - [IOException] → logged via [crashReporter] and rethrown. A disk
 *    failure is a real problem the caller should see; silently swallowing
 *    it would mask outages like a full or corrupt DataStore.
 */
private val Context.encryptedStoreDataStore by
    preferencesDataStore(name = DATA_STORE_NAME)

private const val DATA_STORE_NAME = "snabbit_runner_encrypted_store"
private const val KEYSET_PREFS_FILE = "snabbit_runner_kmp_keyset_prefs"
private const val KEYSET_NAME = "snabbit_runner_kmp_keyset"
private const val MASTER_KEY_ALIAS = "snabbit_runner_kmp_master"
private const val MASTER_KEY_URI = "android-keystore://$MASTER_KEY_ALIAS"
private const val ANDROID_KEYSTORE = "AndroidKeyStore"

class TinkDataStoreEncryptedStore(
    context: Context,
    private val crashReporter: CrashReporter,
) : EncryptedStore {

    private val dataStore = context.applicationContext.encryptedStoreDataStore
    // First instantiation happens on Dispatchers.IO (KmpBootstrap's hydrate
    // coroutine triggers it before any plugin attaches), so the SharedPrefs
    // disk read inside AndroidKeysetManager.build() does not block main.
    private val aead: Aead = buildAead(context.applicationContext)

    /**
     * Builds the AEAD, self-healing a keyset whose master key is gone.
     *
     * The keyset lives in SharedPreferences; its master key lives in the Android
     * Keystore, which is hardware-bound and never leaves the device. A cloud
     * restore or device-to-device transfer therefore brings the keyset back
     * WITHOUT the key that unwraps it, and `build()` throws
     * `InvalidKeyException: Keystore cannot load the key with ID …`.
     *
     * Unguarded, that throw escapes the constructor, Koin fails to create the
     * singleton, and — because Koin singletons resolve lazily from several call
     * sites, not all of them inside KmpBootstrap's try/catch — it reaches the
     * main thread as a fatal crash on launch. A restored runner would be stuck
     * in a crash loop with no way out but reinstalling.
     *
     * Recovery is lossless: a keyset whose master key is missing can never
     * decrypt anything again, so the stored ciphertext is already unreadable.
     * Dropping the keystore alias and the keyset prefs lets Tink mint a fresh
     * pair; the orphaned ciphertext then fails `decryptOrNull` and is reported
     * as absent, which is the documented read policy above. The runner simply
     * signs in again.
     *
     * Reported, never silent — this should be rare, and a rising rate means
     * something worse (failing keystore hardware, an OEM wiping aliases).
     */
    private fun buildAead(app: Context): Aead = try {
        newAead(app)
    } catch (e: GeneralSecurityException) {
        crashReporter.report(e, mapOf("op" to "encryptedStoreInit", "recovery" to "resetKeyset"))
        resetKeysetMaterial(app)
        newAead(app)
    }

    private fun newAead(app: Context): Aead = AndroidKeysetManager.Builder()
        .withSharedPref(app, KEYSET_NAME, KEYSET_PREFS_FILE)
        .withKeyTemplate(KeyTemplates.get("AES256_GCM"))
        .withMasterKeyUri(MASTER_KEY_URI)
        .build()
        .keysetHandle
        .getPrimitive(RegistryConfiguration.get(), Aead::class.java)

    /**
     * Drops both halves of the unusable pair. The alias is deleted too, not just
     * the prefs: if it exists but is unloadable, regenerating the keyset alone
     * would wrap it under the same broken key and fail identically.
     */
    private fun resetKeysetMaterial(app: Context) {
        runCatching {
            KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }.deleteEntry(MASTER_KEY_ALIAS)
        }.onFailure { crashReporter.report(it, mapOf("op" to "encryptedStoreResetAlias")) }
        runCatching {
            app.deleteSharedPreferences(KEYSET_PREFS_FILE)
        }.onFailure { crashReporter.report(it, mapOf("op" to "encryptedStoreResetPrefs")) }
    }

    @Throws(IOException::class)
    override suspend fun getString(key: String): String? {
        val storedBase64 = readSnapshot()[stringPreferencesKey(key)] ?: return null
        return decryptOrNull(key, storedBase64)
    }

    override suspend fun putString(key: String, value: String) {
        val ciphertext = aead.encrypt(
            value.toByteArray(Charsets.UTF_8),
            key.toByteArray(Charsets.UTF_8),
        )
        val base64 = Base64.encodeToString(ciphertext, Base64.NO_WRAP)
        dataStore.edit { it[stringPreferencesKey(key)] = base64 }
    }

    override suspend fun delete(key: String) {
        dataStore.edit { it.remove(stringPreferencesKey(key)) }
    }

    @Throws(IOException::class)
    override suspend fun getAll(keys: Set<String>): Map<String, String> {
        val snapshot = readSnapshot()
        return keys.mapNotNull { key ->
            val stored = snapshot[stringPreferencesKey(key)] ?: return@mapNotNull null
            decryptOrNull(key, stored)?.let { key to it }
        }.toMap()
    }

    /**
     * Single DataStore snapshot read. Wraps any [IOException] with a
     * crash-report side effect and rethrows — disk failures are real and
     * callers should see them rather than getting a misleading `null`.
     */
    private suspend fun readSnapshot(): Preferences = try {
        dataStore.data.first()
    } catch (e: IOException) {
        crashReporter.report(e, mapOf("op" to "datastore_read", "store" to DATA_STORE_NAME))
        throw e
    }

    /**
     * Decrypts `storedBase64` under the per-entry associated data `key`.
     * Returns null on expected failure modes (tamper, key rotation, bad
     * Base64). IOException is impossible here — Tink/Base64 are pure CPU.
     */
    private fun decryptOrNull(key: String, storedBase64: String): String? = try {
        val ciphertext = Base64.decode(storedBase64, Base64.NO_WRAP)
        val plaintext = aead.decrypt(ciphertext, key.toByteArray(Charsets.UTF_8))
        String(plaintext, Charsets.UTF_8)
    } catch (_: GeneralSecurityException) {
        null   // tamper, key rotation, master-key change
    } catch (_: IllegalArgumentException) {
        null   // malformed Base64 — treat as missing
    }
}
