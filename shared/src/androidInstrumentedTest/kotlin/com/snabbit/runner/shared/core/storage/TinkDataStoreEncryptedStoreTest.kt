package com.snabbit.runner.shared.core.storage

import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.google.crypto.tink.aead.AeadConfig
import com.snabbit.runner.shared.core.CrashReporter
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.BeforeClass
import org.junit.Test
import org.junit.runner.RunWith

/**
 * On-device integration test: exercises the real Tink + DataStore +
 * Android Keystore stack. Runs via `:shared:connectedDebugAndroidTest`.
 *
 * Each test cleans the slot it uses in @Before and @After so successive
 * runs are independent.
 */
@RunWith(AndroidJUnit4::class)
class TinkDataStoreEncryptedStoreTest {

    private val context = ApplicationProvider.getApplicationContext<android.content.Context>()
    private val noopReporter = CrashReporter { _, _ -> }
    private val store = TinkDataStoreEncryptedStore(context, noopReporter)

    @Before
    fun clean() = runBlocking {
        KEYS.forEach { store.delete(it) }
    }

    @After
    fun teardown() = runBlocking {
        KEYS.forEach { store.delete(it) }
    }

    @Test
    fun putThenGet_roundTrips() = runBlocking {
        store.putString(K1, "jwt-token-value")
        assertEquals("jwt-token-value", store.getString(K1))
    }

    @Test
    fun get_returnsNull_whenMissing() = runBlocking {
        assertNull(store.getString(K1))
    }

    @Test
    fun delete_removesValue() = runBlocking {
        store.putString(K1, "to-be-deleted")
        store.delete(K1)
        assertNull(store.getString(K1))
    }

    @Test
    fun put_overwritesPreviousValue() = runBlocking {
        store.putString(K1, "first")
        store.putString(K1, "second")
        assertEquals("second", store.getString(K1))
    }

    @Test
    fun differentKeys_areIndependent() = runBlocking {
        store.putString(K1, "value-1")
        store.putString(K2, "value-2")
        assertEquals("value-1", store.getString(K1))
        assertEquals("value-2", store.getString(K2))

        store.delete(K1)
        assertNull(store.getString(K1))
        assertEquals("value-2", store.getString(K2))
    }

    @Test
    fun persistsAcrossInstances() = runBlocking {
        store.putString(K1, "persisted")

        val freshStore = TinkDataStoreEncryptedStore(context, noopReporter)
        assertEquals("persisted", freshStore.getString(K1))
    }

    @Test
    fun ciphertext_differsFromPlaintext() = runBlocking {
        store.putString(K1, "plaintext-with-distinctive-marker")
        assertEquals("plaintext-with-distinctive-marker", store.getString(K1))

        store.putString(K1, "plaintext-with-distinctive-marker")
        assertEquals("plaintext-with-distinctive-marker", store.getString(K1))

        store.putString(K2, "different-plaintext")
        assertNotEquals(store.getString(K1), store.getString(K2))
    }

    companion object {
        @JvmStatic
        @BeforeClass
        fun initTink() {
            AeadConfig.register()
        }

        private const val K1 = "test_key_1"
        private const val K2 = "test_key_2"
        private val KEYS = listOf(K1, K2)
    }
}
