package com.snabbit.runner.shared.storage.internal

import com.snabbit.runner.shared.storage.StorageEvent

import android.content.Context
import android.os.SystemClock
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import com.google.crypto.tink.Aead
import com.google.crypto.tink.KeyTemplates
import com.google.crypto.tink.RegistryConfiguration
import com.google.crypto.tink.integration.android.AndroidKeysetManager
import com.snabbit.runner.shared.core.AppDispatchers
import com.snabbit.runner.shared.core.CrashReporter
import com.snabbit.runner.shared.core.Logger
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import java.io.IOException

/**
 * Manages the Tink AEAD keyset backed by Android Keystore.
 *
 * Pipeline: Android Keystore master key → protects Tink keyset →
 * keyset stored in SharedPreferences → AEAD primitive for AES-256-GCM.
 *
 * The AEAD is lazily created on first access and cached. [getOrCreateAead]
 * is `suspend` and serialized by a [Mutex] (never a thread-blocking
 * `synchronized` + `runBlocking`), so a slow keyset build or DataStore wipe
 * suspends other callers instead of stalling a thread.
 *
 * Failure handling is a taxonomy, not a single "wipe on any error":
 *  - **Transient** ([IOException] reading the keyset prefs): never wipe — the
 *    keyset is probably intact. Back off and retry.
 *  - **Likely keyset/master-key loss** (other exceptions, e.g. corruption or a
 *    key rotated away by a factory reset): only after [WIPE_THRESHOLD]
 *    consecutive failures — so a boot-time hiccup gets retries first — do we
 *    clear the keyset + encrypted DataStore and recreate, and only **once per
 *    failure episode** ([recoveryAttempted]) so a persistent build failure
 *    can't re-wipe on every retry.
 *
 * There is no permanent "dead" latch: failures set an exponential
 * [nextRetryAtMs] backoff (capped), so a transient boot problem recovers on a
 * later call without a process restart.
 */
internal class KeyManager(
    private val context: Context,
    private val secureDataStore: DataStore<Preferences>,
    private val logger: Logger,
    private val crashReporter: CrashReporter,
    private val dispatchers: AppDispatchers,
) {
    @Volatile
    private var cachedAead: Aead? = null

    private val mutex = Mutex()

    // Failure/backoff state — only touched while holding [mutex].
    private var consecutiveFailures = 0
    private var nextRetryAtMs = 0L
    private var recoveryAttempted = false

    suspend fun getOrCreateAead(): Aead? {
        cachedAead?.let { return it }
        return mutex.withLock {
            cachedAead?.let { return it }
            if (SystemClock.elapsedRealtime() < nextRetryAtMs) return null
            withContext(dispatchers.io) { buildOrRecover() }
        }
    }

    /** Build the AEAD; on failure, classify and maybe recover. Holds [mutex]. */
    private suspend fun buildOrRecover(): Aead? {
        try {
            return buildAead().also(::onSuccess)
        } catch (e: IOException) {
            // Transient disk error reading the keyset prefs — do NOT wipe.
            logger.e(TAG, "${StorageEvent.STORAGE_KEYSTORE_ERROR}: keyset read failed (transient)", e)
            crashReporter.report(e, mapOf("op" to "keyManager.build", "class" to "io"))
            onFailure()
            return null
        } catch (e: Exception) {
            // Likely genuine keyset/master-key loss.
            logger.e(TAG, "${StorageEvent.STORAGE_KEYSTORE_ERROR}: keyset init failed", e)
            crashReporter.report(e, mapOf("op" to "keyManager.build", "class" to "security"))
            onFailure()
            if (consecutiveFailures >= WIPE_THRESHOLD && !recoveryAttempted) {
                recoveryAttempted = true
                return recreateKeyset()?.also(::onSuccess)
            }
            return null
        }
    }

    private fun onSuccess(aead: Aead) {
        cachedAead = aead
        consecutiveFailures = 0
        nextRetryAtMs = 0L
        recoveryAttempted = false
    }

    private fun onFailure() {
        consecutiveFailures++
        val shift = (consecutiveFailures - 1).coerceIn(0, MAX_BACKOFF_SHIFT)
        val backoff = BASE_BACKOFF_MS shl shift
        nextRetryAtMs = SystemClock.elapsedRealtime() + backoff
    }

    private fun buildAead(): Aead =
        AndroidKeysetManager.Builder()
            .withSharedPref(context.applicationContext, KEYSET_NAME, KEYSET_PREFS_FILE)
            .withKeyTemplate(KeyTemplates.get("AES256_GCM"))
            .withMasterKeyUri(MASTER_KEY_URI)
            .build()
            .keysetHandle
            .getPrimitive(RegistryConfiguration.get(), Aead::class.java)

    /**
     * Genuine-loss recovery: clear the corrupt keyset prefs and the encrypted
     * DataStore (unreadable under a new key anyway), then rebuild. Suspends
     * (no `runBlocking`); serialization is provided by [mutex] in the caller.
     */
    private suspend fun recreateKeyset(): Aead? = try {
        context.applicationContext
            .getSharedPreferences(KEYSET_PREFS_FILE, Context.MODE_PRIVATE)
            .edit()
            .clear()
            .commit()
        secureDataStore.edit { it.clear() }
        logger.w(TAG, "Cleared corrupted keyset + data; rebuilding")
        buildAead()
    } catch (e: Exception) {
        logger.e(TAG, "${StorageEvent.STORAGE_KEYSTORE_ERROR}: keyset recreation failed", e)
        crashReporter.report(e, mapOf("op" to "keyManager.recreate"))
        null
    }

    internal companion object {
        const val TAG = "KeyManager"
        const val KEYSET_PREFS_FILE = "snabbit_storage_sdk_keyset_prefs"
        const val KEYSET_NAME = "snabbit_storage_sdk_keyset"
        const val MASTER_KEY_URI = "android-keystore://snabbit_storage_sdk_master"

        // Consecutive build failures before we treat it as genuine keyset loss
        // and wipe+recreate (gives transient boot faults time to clear).
        private const val WIPE_THRESHOLD = 3

        // Exponential backoff between retries: 200ms, 400ms, … capped at ~25.6s
        // (BASE_BACKOFF_MS shl MAX_BACKOFF_SHIFT). The shift cap also guards
        // against Long.shl wrap-around.
        private const val BASE_BACKOFF_MS = 200L
        private const val MAX_BACKOFF_SHIFT = 7
    }
}
