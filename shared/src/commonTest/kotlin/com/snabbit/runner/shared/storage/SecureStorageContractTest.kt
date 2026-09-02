package com.snabbit.runner.shared.storage

import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue
import kotlin.test.assertFalse

class SecureStorageContractTest {

    private val storage = InMemorySecureStorage()

    // ── String ──

    @Test
    fun getString_returnsNull_whenKeyMissing() = runTest {
        assertNull(storage.getString("nonexistent"))
    }

    @Test
    fun putString_thenGetString_roundTrips() = runTest {
        storage.putString("token", "abc123")
        assertEquals("abc123", storage.getString("token"))
    }

    @Test
    fun putString_overwritesPreviousValue() = runTest {
        storage.putString("key", "old")
        storage.putString("key", "new")
        assertEquals("new", storage.getString("key"))
    }

    @Test
    fun putString_emptyValue_roundTrips() = runTest {
        storage.putString("key", "")
        assertEquals("", storage.getString("key"))
    }

    // ── Int ──

    @Test
    fun getInt_returnsNull_whenKeyMissing() = runTest {
        assertNull(storage.getInt("nonexistent"))
    }

    @Test
    fun putInt_thenGetInt_roundTrips() = runTest {
        storage.putInt("counter", 42)
        assertEquals(42, storage.getInt("counter"))
    }

    @Test
    fun putInt_overwritesPreviousValue() = runTest {
        storage.putInt("key", 1)
        storage.putInt("key", 2)
        assertEquals(2, storage.getInt("key"))
    }

    @Test
    fun putInt_zero_roundTrips() = runTest {
        storage.putInt("key", 0)
        assertEquals(0, storage.getInt("key"))
    }

    @Test
    fun putInt_negativeValue_roundTrips() = runTest {
        storage.putInt("key", -100)
        assertEquals(-100, storage.getInt("key"))
    }

    // ── Long ──

    @Test
    fun getLong_returnsNull_whenKeyMissing() = runTest {
        assertNull(storage.getLong("nonexistent"))
    }

    @Test
    fun putLong_thenGetLong_roundTrips() = runTest {
        storage.putLong("timestamp", 1718700000000L)
        assertEquals(1718700000000L, storage.getLong("timestamp"))
    }

    @Test
    fun putLong_maxValue_roundTrips() = runTest {
        storage.putLong("key", Long.MAX_VALUE)
        assertEquals(Long.MAX_VALUE, storage.getLong("key"))
    }

    // ── Boolean ──

    @Test
    fun getBool_returnsNull_whenKeyMissing() = runTest {
        assertNull(storage.getBool("nonexistent"))
    }

    @Test
    fun putBool_true_roundTrips() = runTest {
        storage.putBool("flag", true)
        assertTrue(storage.getBool("flag")!!)
    }

    @Test
    fun putBool_false_roundTrips() = runTest {
        storage.putBool("flag", false)
        assertFalse(storage.getBool("flag")!!)
    }

    @Test
    fun putBool_overwritesPreviousValue() = runTest {
        storage.putBool("flag", true)
        storage.putBool("flag", false)
        assertFalse(storage.getBool("flag")!!)
    }

    // ── Double ──

    @Test
    fun getDouble_returnsNull_whenKeyMissing() = runTest {
        assertNull(storage.getDouble("nonexistent"))
    }

    @Test
    fun putDouble_thenGetDouble_roundTrips() = runTest {
        storage.putDouble("volume", 0.75)
        assertEquals(0.75, storage.getDouble("volume")!!, 0.0001)
    }

    @Test
    fun putDouble_zero_roundTrips() = runTest {
        storage.putDouble("key", 0.0)
        assertEquals(0.0, storage.getDouble("key")!!, 0.0001)
    }

    @Test
    fun putDouble_negativeValue_roundTrips() = runTest {
        storage.putDouble("key", -3.14)
        assertEquals(-3.14, storage.getDouble("key")!!, 0.0001)
    }

    // ── remove / clear / independence ──

    @Test
    fun remove_deletesEntry() = runTest {
        storage.putString("key", "value")
        storage.remove("key")
        assertNull(storage.getString("key"))
    }

    @Test
    fun remove_isNoOp_whenKeyMissing() = runTest {
        storage.remove("nonexistent")
    }

    @Test
    fun clear_wipesAllTypes() = runTest {
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
    fun clear_isNoOp_whenEmpty() = runTest {
        storage.clear()
    }

    @Test
    fun differentKeys_areIndependent() = runTest {
        storage.putString("k1", "v1")
        storage.putString("k2", "v2")
        assertEquals("v1", storage.getString("k1"))
        assertEquals("v2", storage.getString("k2"))

        storage.remove("k1")
        assertNull(storage.getString("k1"))
        assertEquals("v2", storage.getString("k2"))
    }

    @Test
    fun remove_typedEntry_returnsNull() = runTest {
        storage.putInt("i", 42)
        storage.putBool("b", true)
        storage.remove("i")
        storage.remove("b")
        assertNull(storage.getInt("i"))
        assertNull(storage.getBool("b"))
    }

    @Test
    fun writes_returnTrue_onSuccess() = runTest {
        assertTrue(storage.putString("s", "v"))
        assertTrue(storage.putInt("i", 1))
        assertTrue(storage.putLong("l", 2L))
        assertTrue(storage.putBool("b", true))
        assertTrue(storage.putDouble("d", 3.0))
        assertTrue(storage.remove("s"))
        assertTrue(storage.clear())
    }
}
