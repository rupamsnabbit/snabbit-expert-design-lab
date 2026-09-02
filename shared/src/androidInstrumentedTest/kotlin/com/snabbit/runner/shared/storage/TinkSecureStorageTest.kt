package com.snabbit.runner.shared.storage

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.google.crypto.tink.aead.AeadConfig
import com.snabbit.runner.shared.core.AppDispatchers
import com.snabbit.runner.shared.core.CrashReporter
import com.snabbit.runner.shared.core.Logger
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.BeforeClass
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class TinkSecureStorageTest {

    private val context = ApplicationProvider.getApplicationContext<Context>()
    private val noopReporter = CrashReporter { _, _ -> }
    private val noopLogger = object : Logger {
        override fun d(tag: String, message: String) {}
        override fun w(tag: String, message: String, throwable: Throwable?) {}
        override fun e(tag: String, message: String, throwable: Throwable?) {}
    }
    private val dataStore = createPreferenceDataStore {
        context.filesDir.resolve("datastore/${TinkSecureStorage.DATASTORE_FILE}").absolutePath
    }
    private val testDispatchers = object : AppDispatchers {
        override val io: CoroutineDispatcher = Dispatchers.Unconfined
        override val default: CoroutineDispatcher = Dispatchers.Unconfined
        override val main: CoroutineDispatcher = Dispatchers.Unconfined
    }
    private val keyManager = KeyManager(context, dataStore, noopLogger, noopReporter, testDispatchers)
    private val storage = TinkSecureStorage(
        dataStore, keyManager, noopLogger, noopReporter,
    )

    companion object {
        @JvmStatic
        @BeforeClass
        fun initTink() {
            AeadConfig.register()
        }
    }

    @Before
    fun setup() {
        runBlocking { storage.clear() }
    }

    @After
    fun teardown() {
        runBlocking { storage.clear() }
    }

    // ── String ──

    @Test
    fun string_roundTrips() = runBlocking {
        storage.putString("token", "jwt-value")
        assertEquals("jwt-value", storage.getString("token"))
    }

    @Test
    fun getString_returnsNull_whenMissing() = runBlocking {
        assertNull(storage.getString("nonexistent"))
    }

    @Test
    fun string_emptyValue_roundTrips() = runBlocking {
        storage.putString("key", "")
        assertEquals("", storage.getString("key"))
    }

    // ── Int ──

    @Test
    fun int_roundTrips() = runBlocking {
        storage.putInt("counter", 42)
        assertEquals(42, storage.getInt("counter"))
    }

    @Test
    fun getInt_returnsNull_whenMissing() = runBlocking {
        assertNull(storage.getInt("nonexistent"))
    }

    @Test
    fun int_zero_roundTrips() = runBlocking {
        storage.putInt("key", 0)
        assertEquals(0, storage.getInt("key"))
    }

    @Test
    fun int_negativeValue_roundTrips() = runBlocking {
        storage.putInt("key", -999)
        assertEquals(-999, storage.getInt("key"))
    }

    // ── Long ──

    @Test
    fun long_roundTrips() = runBlocking {
        storage.putLong("ts", 1718700000000L)
        assertEquals(1718700000000L, storage.getLong("ts"))
    }

    @Test
    fun getLong_returnsNull_whenMissing() = runBlocking {
        assertNull(storage.getLong("nonexistent"))
    }

    // ── Boolean ──

    @Test
    fun bool_true_roundTrips() = runBlocking {
        storage.putBool("flag", true)
        assertTrue(storage.getBool("flag")!!)
    }

    @Test
    fun bool_false_roundTrips() = runBlocking {
        storage.putBool("flag", false)
        assertFalse(storage.getBool("flag")!!)
    }

    @Test
    fun getBool_returnsNull_whenMissing() = runBlocking {
        assertNull(storage.getBool("nonexistent"))
    }

    // ── Double ──

    @Test
    fun double_roundTrips() = runBlocking {
        storage.putDouble("volume", 0.75)
        assertEquals(0.75, storage.getDouble("volume")!!, 0.0001)
    }

    @Test
    fun getDouble_returnsNull_whenMissing() = runBlocking {
        assertNull(storage.getDouble("nonexistent"))
    }

    // ── remove / clear / cross-type ──

    @Test
    fun remove_deletesEntry() = runBlocking {
        storage.putString("key", "value")
        storage.remove("key")
        assertNull(storage.getString("key"))
    }

    @Test
    fun clear_wipesAllTypes() = runBlocking {
        storage.putString("s", "val")
        storage.putInt("i", 1)
        storage.putLong("l", 2L)
        storage.putBool("b", true)
        storage.putDouble("d", 3.0)
        storage.clear()
        assertNull(storage.getString("s"))
        assertNull(storage.getInt("i"))
        assertNull(storage.getLong("l"))
        assertNull(storage.getBool("b"))
        assertNull(storage.getDouble("d"))
    }

    @Test
    fun overwrite_updatesValue() = runBlocking {
        storage.putString("key", "first")
        storage.putString("key", "second")
        assertEquals("second", storage.getString("key"))
    }

    @Test
    fun persistsAcrossInstances() = runBlocking {
        storage.putString("key", "persisted")
        val fresh = TinkSecureStorage(
            dataStore, keyManager, noopLogger, noopReporter,
        )
        assertEquals("persisted", fresh.getString("key"))
    }

    @Test
    fun corruptedPayload_returnsNull_andRetainsCiphertext() = runBlocking {
        dataStore.edit { it[stringPreferencesKey("corrupted")] = "not-valid-ciphertext" }

        assertNull(storage.getString("corrupted"))
        // Policy: keep the ciphertext — a transient crypto fault must not
        // permanently destroy a possibly-recoverable secret.
        assertEquals(
            "not-valid-ciphertext",
            dataStore.data.first()[stringPreferencesKey("corrupted")],
        )
    }

    @Test
    fun corruptedEntry_isRecoverable_afterOverwrite() = runBlocking {
        dataStore.edit { it[stringPreferencesKey("k")] = "not-valid-ciphertext" }
        assertNull(storage.getString("k"))

        assertTrue(storage.putString("k", "fresh"))
        assertEquals("fresh", storage.getString("k"))
    }

    @Test
    fun writes_returnTrue_onSuccess() = runBlocking {
        assertTrue(storage.putString("s", "v"))
        assertTrue(storage.remove("s"))
        assertTrue(storage.clear())
    }

    @Test
    fun differentKeys_areIndependent() = runBlocking {
        storage.putString("k1", "v1")
        storage.putString("k2", "v2")
        assertEquals("v1", storage.getString("k1"))
        assertEquals("v2", storage.getString("k2"))

        storage.remove("k1")
        assertNull(storage.getString("k1"))
        assertEquals("v2", storage.getString("k2"))
    }
}
