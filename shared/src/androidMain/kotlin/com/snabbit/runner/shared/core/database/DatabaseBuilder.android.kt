package com.snabbit.runner.shared.core.database

import android.content.Context
import androidx.room.Room
import androidx.sqlite.driver.bundled.BundledSQLiteDriver
import kotlinx.coroutines.Dispatchers

/**
 * Android construction of [SnabbitDatabase] (bundled SQLite driver, IO
 * coroutine context — the Room-KMP documented setup). Host-constructed like
 * the engine; Koin wiring arrives with WS4.
 */
fun snabbitDatabase(context: Context): SnabbitDatabase =
    Room.databaseBuilder<SnabbitDatabase>(
        context = context.applicationContext,
        name = context.getDatabasePath(SnabbitDatabase.FILE_NAME).absolutePath,
    )
        .setDriver(BundledSQLiteDriver())
        .setQueryCoroutineContext(Dispatchers.IO)
        .build()
