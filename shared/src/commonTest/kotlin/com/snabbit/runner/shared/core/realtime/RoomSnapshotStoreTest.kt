package com.snabbit.runner.shared.core.realtime

import com.snabbit.runner.shared.core.database.RunnerHomeStateDao
import com.snabbit.runner.shared.core.database.RunnerHomeStateEntity
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

/**
 * The fake overrides only Room's generated members (get/observe/upsert) —
 * [RunnerHomeStateDao.applyIfNewer] runs the REAL default-method gate, so this
 * covers the WS1 gate logic + entity mapping without a device. Persistence
 * across DB reopen stays a device-side instrumented test (LLD App A).
 */
private class FakeDao : RunnerHomeStateDao {
    val rows = MutableStateFlow<RunnerHomeStateEntity?>(null)
    override suspend fun get(runnerId: Long): RunnerHomeStateEntity? =
        rows.value?.takeIf { it.runnerId == runnerId }
    override fun observe(runnerId: Long): Flow<RunnerHomeStateEntity?> = rows
    override suspend fun upsert(entity: RunnerHomeStateEntity) { rows.value = entity }
}

class RoomSnapshotStoreTest {

    private fun snap(epoch: Long, seq: Long, source: SnapshotSource = SnapshotSource.MQTT) =
        AppliedSnapshot(epoch = epoch, stateSeq = seq, widgetJson = """{"name":"X"}""", source = source)

    @Test
    fun gate_and_mapping_round_trip() = runTest {
        val dao = FakeDao()
        val store = RoomSnapshotStore(dao, runnerId = 42, nowMs = { 1_000L })

        assertEquals(true, store.applyIfNewer(snap(0, 10)))
        assertEquals(false, store.applyIfNewer(snap(0, 10)), "equal seq = no-op")
        assertEquals(false, store.applyIfNewer(snap(0, 9)), "lower seq discarded")
        assertEquals(false, store.applyIfNewer(snap(9, 2)), "lower seq discarded — epoch ignored")
        assertEquals(true, store.applyIfNewer(snap(5, 11)), "higher seq applied")

        val current = store.current()
        assertEquals(11, current?.stateSeq)
        assertEquals(5, current?.epoch, "epoch still persisted (round-trips), just not used for ordering")
        assertEquals(SnapshotSource.MQTT, current?.source)
        assertEquals(42, dao.rows.value?.runnerId)
        assertEquals(1_000L, dao.rows.value?.updatedAtMs)
    }

    @Test
    fun observe_mapsRowToApplied_nullWhenEmpty() = runTest {
        val dao = FakeDao()
        val store = RoomSnapshotStore(dao, runnerId = 42, nowMs = { 1_000L })
        assertNull(store.observe().first(), "empty row maps to null")

        store.applyIfNewer(snap(3, 7))
        val emitted = store.observe().first()
        assertEquals(7, emitted?.stateSeq)
        assertEquals(3, emitted?.epoch)
        assertEquals(SnapshotSource.MQTT, emitted?.source)
    }
}
