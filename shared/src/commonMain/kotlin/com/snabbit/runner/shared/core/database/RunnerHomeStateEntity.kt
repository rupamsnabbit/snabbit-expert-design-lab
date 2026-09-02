package com.snabbit.runner.shared.core.database

import androidx.room.Entity
import androidx.room.PrimaryKey

/**
 * The persisted realtime snapshot row (LLD §5.2 `runner_home_state`) —
 * single row per runner; (epoch, stateSeq) is the version gate.
 */
@Entity(tableName = "runner_home_state")
data class RunnerHomeStateEntity(
    @PrimaryKey val runnerId: Long,
    val epoch: Long,
    val stateSeq: Long,
    val widgetJson: String,
    val updatedAtMs: Long,
    /** [com.snabbit.runner.shared.core.realtime.SnapshotSource] name. */
    val source: String,
)
