package com.snabbit.runner.shared.core.storage

import kotlinx.coroutines.async
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull

class StoreManagerImplTest {

    private val store = InMemoryEncryptedStore()
    private val manager = StoreManagerImpl(store)

    @Test
    fun tokenSnapshot_isNull_initially() {
        assertNull(manager.tokenSnapshot())
    }

    @Test
    fun pushToken_updatesSnapshotAndStore() = runTest {
        manager.pushToken("abc")
        assertEquals("abc", manager.tokenSnapshot())
        assertEquals("abc", store.getString("bearer_token"))
    }

    @Test
    fun pushTokenNull_clearsSnapshotAndStore() = runTest {
        manager.pushToken("abc")
        manager.pushToken(null)
        assertNull(manager.tokenSnapshot())
        assertNull(store.getString("bearer_token"))
    }

    @Test
    fun clearToken_wipesBothLayers() = runTest {
        manager.pushToken("abc")
        manager.clearToken()
        assertNull(manager.tokenSnapshot())
        assertNull(store.getString("bearer_token"))
    }

    @Test
    fun hydrateAll_restoresPersistedToken() = runTest {
        // Simulate a previous process having written a token.
        store.putString("bearer_token", "persisted-jwt")

        // Fresh manager → snapshot empty until hydrate.
        val fresh = StoreManagerImpl(store)
        assertNull(fresh.tokenSnapshot())

        fresh.hydrateAll()
        assertEquals("persisted-jwt", fresh.tokenSnapshot())
    }

    @Test
    fun hydrateAll_ignoresBlankPersistedToken() = runTest {
        store.putString("bearer_token", "")
        val fresh = StoreManagerImpl(store)
        fresh.hydrateAll()
        assertNull(fresh.tokenSnapshot())
    }

    @Test
    fun hydrateAll_isSafe_whenNothingPersisted() = runTest {
        val fresh = StoreManagerImpl(InMemoryEncryptedStore())
        fresh.hydrateAll()
        assertNull(fresh.tokenSnapshot())
    }

    @Test
    fun pushToken_overwritesPrevious() = runTest {
        manager.pushToken("old")
        manager.pushToken("new")
        assertEquals("new", manager.tokenSnapshot())
        assertEquals("new", store.getString("bearer_token"))
    }

    @Test
    fun awaitToken_returnsToken_afterPushToken() = runTest {
        // An explicit push opens the gate without a hydrateAll call.
        manager.pushToken("abc")
        assertEquals("abc", manager.awaitToken())
    }

    @Test
    fun awaitToken_returnsNull_afterHydrate_whenLoggedOut() = runTest {
        val fresh = StoreManagerImpl(InMemoryEncryptedStore())
        fresh.hydrateAll()
        assertNull(fresh.awaitToken())
    }

    @Test
    fun awaitToken_suspendsUntilHydrated_thenReturnsRestoredToken() = runTest {
        // Simulate a previous process having written a token to disk.
        store.putString("bearer_token", "cold-jwt")
        val fresh = StoreManagerImpl(store)

        // A request that outraces hydration parks on the gate...
        val deferred = async { fresh.awaitToken() }
        runCurrent()
        assertFalse(deferred.isCompleted)

        // ...and resumes with the restored token once hydrate completes.
        fresh.hydrateAll()
        assertEquals("cold-jwt", deferred.await())
    }

    @Test
    fun hydrateAll_usesSingleStoreReadRegardlessOfKeyCount() = runTest {
        // Single getAll snapshot, not N getString calls — addresses the
        // reviewer's N-disk-read concern.
        store.putString("bearer_token", "jwt")

        val fresh = StoreManagerImpl(store)
        fresh.hydrateAll()

        assertEquals(1, store.getAllCalls)
        assertEquals(0, store.getStringCalls)
    }
}
