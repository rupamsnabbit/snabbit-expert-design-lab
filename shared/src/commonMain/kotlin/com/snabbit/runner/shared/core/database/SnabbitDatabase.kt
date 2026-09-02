package com.snabbit.runner.shared.core.database

import androidx.room.ConstructedBy
import androidx.room.Database
import androidx.room.RoomDatabase
import androidx.room.RoomDatabaseConstructor

/**
 * The shared operational database (LLD §5.1 core/database policy): ONE
 * RoomDatabase, per-feature DAOs. Realtime is the first tenant; IoT joins on
 * its KMP migration; Shield gets its own encrypted instance via this module.
 */
@Database(
    entities = [RunnerHomeStateEntity::class],
    version = 1,
    exportSchema = true,
)
@ConstructedBy(SnabbitDatabaseConstructor::class)
abstract class SnabbitDatabase : RoomDatabase() {
    abstract fun runnerHomeStateDao(): RunnerHomeStateDao

    companion object {
        const val FILE_NAME = "snabbit_shared.db"
    }
}

/** Actuals are generated per-target by the Room KSP compiler. */
@Suppress("KotlinNoActualForExpect", "NO_ACTUAL_FOR_EXPECT")
expect object SnabbitDatabaseConstructor : RoomDatabaseConstructor<SnabbitDatabase> {
    override fun initialize(): SnabbitDatabase
}
