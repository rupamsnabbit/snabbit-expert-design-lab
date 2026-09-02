package com.snabbit.runner.shared.storage.internal

import com.snabbit.runner.shared.storage.PreferenceStorage
import com.snabbit.runner.shared.storage.SecureStorage
import com.snabbit.runner.shared.storage.StorageFactory

/**
 * Platform-agnostic [StorageFactory]. Delegates to the Koin-provided
 * singleton [SecureStorage] and [PreferenceStorage] for the current target
 * (Tink+DataStore / Keychain on Android / iOS respectively).
 */
internal class DefaultStorageFactory(
    private val secure: SecureStorage,
    private val preference: PreferenceStorage,
) : StorageFactory {

    override fun secureStorage(): SecureStorage = secure

    override fun preferenceStorage(): PreferenceStorage = preference
}
