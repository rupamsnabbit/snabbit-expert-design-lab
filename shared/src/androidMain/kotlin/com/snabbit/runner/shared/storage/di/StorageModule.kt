package com.snabbit.runner.shared.storage.di

import android.app.Application
import com.snabbit.runner.shared.storage.internal.DataStorePreferenceStorage
import com.snabbit.runner.shared.storage.internal.DefaultStorageFactory
import com.snabbit.runner.shared.storage.internal.KeyManager
import com.snabbit.runner.shared.storage.PreferenceStorage
import com.snabbit.runner.shared.storage.SecureStorage
import com.snabbit.runner.shared.storage.StorageFactory
import com.snabbit.runner.shared.storage.internal.TinkSecureStorage
import com.snabbit.runner.shared.storage.internal.createPreferenceDataStore
import org.koin.dsl.module

/**
 * Koin module for the storage SDK. Requires [com.snabbit.runner.shared.core.di.platformModule]
 * to have already bound [com.snabbit.runner.shared.core.Logger],
 * [com.snabbit.runner.shared.core.CrashReporter] and
 * [com.snabbit.runner.shared.core.AppDispatchers].
 *
 * Consumers inject [StorageFactory] and call [StorageFactory.secureStorage] /
 * [StorageFactory.preferenceStorage]. Direct injection of [SecureStorage] or
 * [PreferenceStorage] is also supported for convenience.
 */
fun storageModule(app: Application) = module {
    val secureDataStore = createPreferenceDataStore {
        app.filesDir.resolve("datastore/${TinkSecureStorage.DATASTORE_FILE}").absolutePath
    }
    val preferenceDataStore = createPreferenceDataStore {
        app.filesDir.resolve("datastore/${DataStorePreferenceStorage.DATASTORE_FILE}").absolutePath
    }

    single { KeyManager(app, secureDataStore, get(), get(), get()) }
    single<SecureStorage> { TinkSecureStorage(secureDataStore, get(), get(), get()) }
    single<PreferenceStorage> { DataStorePreferenceStorage(preferenceDataStore, get(), get()) }
    single<StorageFactory> { DefaultStorageFactory(get(), get()) }
}
