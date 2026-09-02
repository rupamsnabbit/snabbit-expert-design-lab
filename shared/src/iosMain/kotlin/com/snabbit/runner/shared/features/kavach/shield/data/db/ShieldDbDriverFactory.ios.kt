package com.snabbit.runner.shared.features.kavach.shield.data.db

import app.cash.sqldelight.db.SqlDriver
import app.cash.sqldelight.driver.native.NativeSqliteDriver

actual class ShieldDbDriverFactory {
    actual fun create(): SqlDriver =
        NativeSqliteDriver(ShieldDatabase.Schema, SHIELD_DB_NAME)
}
