package com.snabbit.runner.shared.storage

/**
 * Convenience single entry point for obtaining storage instances: inject
 * [StorageFactory] and call [secureStorage] / [preferenceStorage] instead of
 * wiring both bindings separately.
 *
 * This is a convenience, not a load-bearing abstraction. Koin already binds
 * [SecureStorage] and [PreferenceStorage] *by interface*, so a common consumer
 * can inject either directly (`get<SecureStorage>()`) and never reference the
 * platform impl (`TinkSecureStorage` / `KeychainSecureStorage`) — the interface
 * binding is what hides the platform type, not this factory. Keep it if a single
 * handle for both tiers reads better; it can equally be collapsed to direct
 * interface injection without leaking platform types.
 */
interface StorageFactory {

    fun secureStorage(): SecureStorage

    fun preferenceStorage(): PreferenceStorage
}
