@file:OptIn(kotlinx.cinterop.ExperimentalForeignApi::class)

package com.snabbit.runner.shared.storage.di

import com.snabbit.runner.shared.core.Logger
import com.snabbit.runner.shared.storage.internal.DataStorePreferenceStorage
import com.snabbit.runner.shared.storage.internal.DefaultStorageFactory
import com.snabbit.runner.shared.storage.internal.KeychainSecureStorage
import com.snabbit.runner.shared.storage.PreferenceStorage
import com.snabbit.runner.shared.storage.SecureStorage
import com.snabbit.runner.shared.storage.StorageFactory
import com.snabbit.runner.shared.storage.internal.createPreferenceDataStore
import kotlinx.cinterop.ExperimentalForeignApi
import org.koin.dsl.module
import platform.Foundation.NSDocumentDirectory
import platform.Foundation.NSFileManager
import platform.Foundation.NSUserDomainMask

/**
 * iOS storage wiring — parity with Android's
 * [com.snabbit.runner.shared.storage.di.storageModule]:
 *  - [SecureStorage]     → [KeychainSecureStorage] (Keychain Services)
 *  - [PreferenceStorage] → [DataStorePreferenceStorage] (DataStore, KMP)
 *  - [StorageFactory]    → [DefaultStorageFactory]
 *
 * Assumes the iOS platform assembly binds [com.snabbit.runner.shared.core.Logger],
 * [com.snabbit.runner.shared.core.CrashReporter] and
 * [com.snabbit.runner.shared.core.AppDispatchers] (as Android's `platformModule`
 * does) before this module is loaded.
 */
fun iosStorageModule() = module {
    single<SecureStorage> {
        KeychainSecureStorage(KEYCHAIN_SERVICE, get(), get(), get())
    }
    single<PreferenceStorage> {
        val logger = get<Logger>()
        val dataStore = createPreferenceDataStore {
            "${documentsDirectory(logger)}/${DataStorePreferenceStorage.DATASTORE_FILE}"
        }
        DataStorePreferenceStorage(dataStore, logger, get())
    }
    single<StorageFactory> { DefaultStorageFactory(get(), get()) }
}

/** Keychain service namespace for all [SecureStorage] items on iOS. */
private const val KEYCHAIN_SERVICE = "com.snabbit.runner.secure_storage"

private const val TAG = "IosStorageModule"

/**
 * Absolute path to the app's Documents directory. Null-safe: if the platform
 * cannot resolve it (should never happen on iOS), log and fail loudly rather
 * than NPE deep inside DataStore.
 */
@OptIn(ExperimentalForeignApi::class)
private fun documentsDirectory(logger: Logger): String =
    NSFileManager.defaultManager.URLForDirectory(
        directory = NSDocumentDirectory,
        inDomain = NSUserDomainMask,
        appropriateForURL = null,
        create = true,
        error = null,
    )?.path ?: run {
        logger.e(TAG, "NSDocumentDirectory unavailable; cannot resolve DataStore path")
        error("NSDocumentDirectory unavailable for PreferenceStorage DataStore path")
    }
