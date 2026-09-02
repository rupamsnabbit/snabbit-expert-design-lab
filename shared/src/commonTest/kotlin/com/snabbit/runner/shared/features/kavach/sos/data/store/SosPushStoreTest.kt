package com.snabbit.runner.shared.features.kavach.sos.data.store

import com.snabbit.runner.shared.core.storage.InMemoryEncryptedStore
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class SosPushStoreTest {

    private val key = "pending_shield_sos_action"

    @Test
    fun persist_peek_returns_thenClearRemoves() = runTest {
        val store = SosPushStore(InMemoryEncryptedStore())
        store.persist("confirm", 42)
        val peeked = store.peek()
        assertEquals("confirm", peeked?.action)
        assertEquals(42, peeked?.sosId)
        assertEquals("confirm", store.peek()?.action)   // peek does NOT consume (ack-then-delete)
        store.clear()
        assertNull(store.peek())                          // removed only after clear()
    }

    @Test
    fun peek_empty_isNull() = runTest {
        assertNull(SosPushStore(InMemoryEncryptedStore()).peek())
    }

    @Test
    fun peek_malformed_returnsNull_andRetainsForRetry() = runTest {
        val es = InMemoryEncryptedStore()
        es.putString(key, "not-json")
        val store = SosPushStore(es)
        assertNull(store.peek())                       // decode fails → null
        assertEquals("not-json", es.getString(key))    // NOT deleted (retry, not lost)
    }
}
