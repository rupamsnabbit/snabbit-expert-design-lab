package com.snabbit.runner.shared.core.network

import com.snabbit.runner.shared.core.camera.fakes.TestAppDispatchers
import com.snabbit.runner.shared.storage.InMemoryPreferenceStorage
import kotlinx.coroutines.async
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

class NetworkConfigStoreTest {

    @Test
    fun snapshot_isNull_beforePush() {
        val store = NetworkConfigStore()
        assertNull(store.snapshot())
    }

    @Test
    fun pushNetworkConfig_populatesSnapshot() {
        val store = NetworkConfigStore()
        store.pushNetworkConfig("https://example.com/", "100")
        assertEquals(NetworkConfig("https://example.com/", "100"), store.snapshot())
    }

    @Test
    fun pushNetworkConfig_trimsWhitespace() {
        val store = NetworkConfigStore()
        store.pushNetworkConfig("  https://example.com/  ", "  100 ")
        assertEquals("https://example.com/", store.snapshot()!!.baseUrl)
        assertEquals("100", store.snapshot()!!.versionCode)
    }

    @Test
    fun awaitReady_suspends_untilFirstPush() = runTest {
        val store = NetworkConfigStore()

        val deferred = async { store.awaitReady() }
        // No push yet — the coroutine should still be suspended.
        assertTrue(deferred.isActive)

        store.pushNetworkConfig("https://example.com/", "100")

        val config = deferred.await()
        assertEquals("https://example.com/", config.baseUrl)
        assertEquals("100", config.versionCode)
    }

    @Test
    fun awaitReady_skipsBlankBaseUrl() = runTest {
        val store = NetworkConfigStore()

        val deferred = async { store.awaitReady() }
        store.pushNetworkConfig("   ", "100") // blank after trim — gate stays closed
        assertTrue(deferred.isActive)

        store.pushNetworkConfig("https://example.com/", "100")
        assertEquals("https://example.com/", deferred.await().baseUrl)
    }

    @Test
    fun awaitReady_returnsImmediately_whenAlreadyPushed() = runTest {
        val store = NetworkConfigStore()
        store.pushNetworkConfig("https://example.com/", "100")

        val config = store.awaitReady()
        assertEquals("https://example.com/", config.baseUrl)
    }

    @Test
    fun pushNetworkConfig_isIdempotent() {
        val store = NetworkConfigStore()
        store.pushNetworkConfig("https://example.com/", "100")
        store.pushNetworkConfig("https://example.com/", "100")
        assertEquals(NetworkConfig("https://example.com/", "100"), store.snapshot())
    }

    // -- Cold-start persistence + seed (Phase B) --

    @Test
    fun pushNetworkConfig_persistsToPreferenceStorage() = runTest {
        val prefs = InMemoryPreferenceStorage()
        val store = NetworkConfigStore(prefs, TestAppDispatchers(UnconfinedTestDispatcher(testScheduler)))

        store.pushNetworkConfig("https://example.com/", "100")
        advanceUntilIdle() // let the fire-and-forget persist complete

        assertEquals("https://example.com/", prefs.getString("net_base_url"))
        assertEquals("100", prefs.getString("net_version_code"))
    }

    @Test
    fun seedFromCache_restoresPersistedConfig_openingTheGate() = runTest {
        val prefs = InMemoryPreferenceStorage()
        prefs.putString("net_base_url", "https://cached.example.com/")
        prefs.putString("net_version_code", "42")
        val store = NetworkConfigStore(prefs, TestAppDispatchers(UnconfinedTestDispatcher(testScheduler)))
        assertNull(store.snapshot())

        store.seedFromCache()

        assertEquals("https://cached.example.com/", store.awaitReady().baseUrl)
        assertEquals("42", store.snapshot()!!.versionCode)
    }

    @Test
    fun seedFromCache_isNoOp_whenNothingPersisted() = runTest {
        val store = NetworkConfigStore(
            InMemoryPreferenceStorage(),
            TestAppDispatchers(UnconfinedTestDispatcher(testScheduler)),
        )
        store.seedFromCache()
        assertNull(store.snapshot())
    }

    @Test
    fun seedFromCache_doesNotClobberAFreshPush() = runTest {
        val prefs = InMemoryPreferenceStorage()
        prefs.putString("net_base_url", "https://cached.example.com/")
        prefs.putString("net_version_code", "1")
        val store = NetworkConfigStore(prefs, TestAppDispatchers(UnconfinedTestDispatcher(testScheduler)))

        // A fresh push lands before the cold seed runs — seed must not overwrite it.
        store.pushNetworkConfig("https://fresh.example.com/", "2")
        store.seedFromCache()

        assertEquals("https://fresh.example.com/", store.snapshot()!!.baseUrl)
    }
}
