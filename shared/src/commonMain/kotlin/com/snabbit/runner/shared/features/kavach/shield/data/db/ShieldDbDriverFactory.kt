package com.snabbit.runner.shared.features.kavach.shield.data.db

import app.cash.sqldelight.db.SqlDriver

/**
 * Platform seam for the SQLDelight driver behind [ShieldDatabase] (Step 7 upload outbox).
 * Android needs a `Context` (supplied via the actual ctor); iOS needs nothing.
 */
expect class ShieldDbDriverFactory {
    fun create(): SqlDriver
}

internal const val SHIELD_DB_NAME = "shield_uploads.db"
