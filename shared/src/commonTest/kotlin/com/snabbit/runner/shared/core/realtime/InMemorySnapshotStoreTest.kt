package com.snabbit.runner.shared.core.realtime

import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class InMemorySnapshotStoreTest {

    private fun snap(epoch: Long, seq: Long) =
        AppliedSnapshot(epoch = epoch, stateSeq = seq, widgetJson = "{}", source = SnapshotSource.MQTT)

    @Test
    fun apply_gate_table() = runTest {
        // (storedEpoch, storedSeq, candEpoch, candSeq, expectApplied) — ordering by state_seq only
        val cases = listOf(
            longArrayOf(0, 10, 0, 11, 1),  // newer seq
            longArrayOf(0, 10, 0, 10, 0),  // equal = no-op
            longArrayOf(0, 10, 0, 9, 0),   // lower = discard (out-of-order)
            longArrayOf(8, 2, 7, 1043, 1), // higher seq applied — epoch ignored
            longArrayOf(7, 1043, 8, 2, 0), // lower seq rejected — epoch ignored
        )
        for (c in cases) {
            val store = InMemorySnapshotStore()
            store.applyIfNewer(snap(c[0], c[1]))
            val applied = store.applyIfNewer(snap(c[2], c[3]))
            assertEquals(c[4] == 1L, applied, "case ${c.toList()}")
        }
    }

    @Test
    fun first_apply_always_succeeds() = runTest {
        assertEquals(true, InMemorySnapshotStore().applyIfNewer(snap(0, 1)))
    }

    @Test
    fun observe_replaysCurrent_andEmitsOnApply() = runTest {
        val store = InMemorySnapshotStore()
        assertNull(store.observe().first(), "nothing applied yet")

        store.applyIfNewer(snap(0, 3))
        assertEquals(3, store.observe().first()?.stateSeq, "reflects the applied row")

        store.applyIfNewer(snap(0, 2)) // stale — gate rejects, observe unchanged
        assertEquals(3, store.observe().first()?.stateSeq)
    }
}
