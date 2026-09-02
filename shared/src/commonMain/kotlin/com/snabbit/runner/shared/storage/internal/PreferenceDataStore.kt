package com.snabbit.runner.shared.storage.internal

import androidx.datastore.core.DataStore
import androidx.datastore.core.handlers.ReplaceFileCorruptionHandler
import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.emptyPreferences
import okio.Path.Companion.toPath

internal fun createPreferenceDataStore(producePath: () -> String): DataStore<Preferences> =
    PreferenceDataStoreFactory.createWithPath(
        // Self-heal a corrupt .preferences_pb instead of surfacing a permanent
        // CorruptionException on every access — the file is already unreadable.
        corruptionHandler = ReplaceFileCorruptionHandler { emptyPreferences() },
        produceFile = { producePath().toPath() },
    )
