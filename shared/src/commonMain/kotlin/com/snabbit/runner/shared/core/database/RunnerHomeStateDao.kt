package com.snabbit.runner.shared.core.database

import androidx.room.Dao
import androidx.room.Query
import androidx.room.Transaction
import androidx.room.Upsert
import com.snabbit.runner.shared.core.realtime.isNewer
import kotlinx.coroutines.flow.Flow

@Dao
interface RunnerHomeStateDao {

    @Query("SELECT * FROM runner_home_state WHERE runnerId = :runnerId")
    suspend fun get(runnerId: Long): RunnerHomeStateEntity?

    @Query("SELECT * FROM runner_home_state WHERE runnerId = :runnerId")
    fun observe(runnerId: Long): Flow<RunnerHomeStateEntity?>

    @Upsert
    suspend fun upsert(entity: RunnerHomeStateEntity)

    /**
     * THE version gate, transactional: stores [candidate] iff its `stateSeq`
     * is strictly greater than the stored row (ordering by `state_seq` only —
     * see [isNewer]). A crash mid-apply leaves the row fully at N or N-1 —
     * never torn.
     *
     * @return true iff applied.
     */
    @Transaction
    suspend fun applyIfNewer(candidate: RunnerHomeStateEntity): Boolean {
        val current = get(candidate.runnerId)
        val newer = current == null ||
            isNewer(candidate.stateSeq, current.stateSeq)
        if (newer) upsert(candidate)
        return newer
    }
}
