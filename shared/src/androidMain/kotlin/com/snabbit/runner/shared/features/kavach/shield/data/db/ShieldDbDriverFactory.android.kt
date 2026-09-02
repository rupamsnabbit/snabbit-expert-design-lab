package com.snabbit.runner.shared.features.kavach.shield.data.db

import android.content.Context
import app.cash.sqldelight.db.SqlDriver
import app.cash.sqldelight.driver.android.AndroidSqliteDriver

actual class ShieldDbDriverFactory(private val context: Context) {
    actual fun create(): SqlDriver =
        AndroidSqliteDriver(ShieldDatabase.Schema, context, SHIELD_DB_NAME)
}
