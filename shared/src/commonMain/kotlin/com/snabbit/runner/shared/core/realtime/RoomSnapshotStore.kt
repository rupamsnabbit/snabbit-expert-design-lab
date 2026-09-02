package com.snabbit.runner.shared.core.realtime

import com.snabbit.runner.shared.core.database.RunnerHomeStateDao
import com.snabbit.runner.shared.core.database.RunnerHomeStateEntity
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

/**
 * The WS1 [SnapshotStore]: persistence + the version gate live in the DAO's
 * @Transaction (LLD §6.3); this class only maps shapes. Survives process
 * death — the store IS the offline-first first-paint source (LLD §7).
 */
class RoomSnapshotStore(
    private val dao: RunnerHomeStateDao,
    private val runnerId: Long,
    private val nowMs: () -> Long,
) : SnapshotStore {

    override suspend fun current(): AppliedSnapshot? = dao.get(runnerId)?.toApplied()

    // Room emits the current row on subscription then on every upsert, so the
    // DB-source projection first-paints from the persisted snapshot with no
    // network round-trip (LLD §7) and stays live thereafter.
    override fun observe(): Flow<AppliedSnapshot?> =
        dao.observe(runnerId).map { it?.toApplied() }

    override suspend fun applyIfNewer(candidate: AppliedSnapshot): Boolean =
        dao.applyIfNewer(candidate.toEntity(runnerId = runnerId, updatedAtMs = nowMs()))
}

private fun RunnerHomeStateEntity.toApplied() = AppliedSnapshot(
    epoch = epoch,
    stateSeq = stateSeq,
    widgetJson = widgetJson,
    source = runCatching { SnapshotSource.valueOf(source) }.getOrDefault(SnapshotSource.MQTT),
)

private fun AppliedSnapshot.toEntity(runnerId: Long, updatedAtMs: Long) = RunnerHomeStateEntity(
    runnerId = runnerId,
    epoch = epoch,
    stateSeq = stateSeq,
    widgetJson = widgetJson,
    updatedAtMs = updatedAtMs,
    source = source.name,
)
