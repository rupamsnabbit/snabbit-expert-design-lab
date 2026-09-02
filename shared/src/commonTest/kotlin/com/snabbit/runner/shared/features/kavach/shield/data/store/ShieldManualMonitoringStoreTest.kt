package com.snabbit.runner.shared.features.kavach.shield.data.store

import com.snabbit.runner.shared.core.storage.InMemoryEncryptedStore
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class ShieldManualMonitoringStoreTest {

    @Test
    fun setActiveJob_thenActiveJobId_returnsIt() = runTest {
        val store = ShieldManualMonitoringStore(InMemoryEncryptedStore())
        assertNull(store.activeJobId())
        store.setActiveJob(650)
        assertEquals(650, store.activeJobId())
    }

    @Test
    fun clear_dropsTheJob() = runTest {
        val store = ShieldManualMonitoringStore(InMemoryEncryptedStore())
        store.setActiveJob(650)
        store.clear()
        assertNull(store.activeJobId())
    }
}
