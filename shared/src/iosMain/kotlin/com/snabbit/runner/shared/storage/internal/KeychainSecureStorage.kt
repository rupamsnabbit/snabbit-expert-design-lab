@file:OptIn(ExperimentalForeignApi::class, BetaInteropApi::class)

package com.snabbit.runner.shared.storage.internal

import com.snabbit.runner.shared.storage.SecureStorage
import com.snabbit.runner.shared.storage.StorageEvent

import com.snabbit.runner.shared.core.AppDispatchers
import com.snabbit.runner.shared.core.CrashReporter
import com.snabbit.runner.shared.core.Logger
import kotlinx.cinterop.BetaInteropApi
import kotlinx.cinterop.CArrayPointer
import kotlinx.cinterop.COpaquePointerVar
import kotlinx.cinterop.ExperimentalForeignApi
import kotlinx.cinterop.NativePlacement
import kotlinx.cinterop.alloc
import kotlinx.cinterop.allocArray
import kotlinx.cinterop.convert
import kotlinx.cinterop.memScoped
import kotlinx.cinterop.ptr
import kotlinx.cinterop.set
import kotlinx.cinterop.value
import kotlinx.coroutines.withContext
import platform.CoreFoundation.CFDictionaryCreate
import platform.CoreFoundation.CFDictionaryRef
import platform.CoreFoundation.CFRelease
import platform.CoreFoundation.CFStringRef
import platform.CoreFoundation.CFTypeRef
import platform.CoreFoundation.CFTypeRefVar
import platform.CoreFoundation.kCFAllocatorDefault
import platform.CoreFoundation.kCFBooleanTrue
import platform.CoreFoundation.kCFTypeDictionaryKeyCallBacks
import platform.CoreFoundation.kCFTypeDictionaryValueCallBacks
import platform.Foundation.CFBridgingRelease
import platform.Foundation.CFBridgingRetain
import platform.Foundation.NSData
import platform.Foundation.NSString
import platform.Foundation.NSUTF8StringEncoding
import platform.Foundation.create
import platform.Foundation.dataUsingEncoding
import platform.Security.SecItemAdd
import platform.Security.SecItemCopyMatching
import platform.Security.SecItemDelete
import platform.Security.SecItemUpdate
import platform.Security.errSecDuplicateItem
import platform.Security.errSecItemNotFound
import platform.Security.errSecSuccess
import platform.Security.kSecAttrAccessible
import platform.Security.kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
import platform.Security.kSecAttrAccount
import platform.Security.kSecAttrService
import platform.Security.kSecClass
import platform.Security.kSecClassGenericPassword
import platform.Security.kSecMatchLimit
import platform.Security.kSecMatchLimitOne
import platform.Security.kSecReturnData
import platform.Security.kSecValueData
import platform.darwin.OSStatus

/**
 * [SecureStorage] for iOS backed by **Keychain Services** (the `Security`
 * framework) — the Apple-native counterpart to Android's Tink + Keystore.
 *
 * The iOS Keychain *is* the encrypted store: entries are encrypted at rest
 * with a hardware-backed key (Secure Enclave where available), so — unlike
 * Android, where Tink encrypts and DataStore persists — there is no separate
 * encrypt-then-persist pipeline here. Keychain does both.
 *
 * Item model: one `kSecClassGenericPassword` entry per key, namespaced by
 * [service] ([kSecAttrService]) with the storage key as [kSecAttrAccount].
 * All values are stored as UTF-8 bytes (same serialize-through-string
 * contract as [com.snabbit.runner.shared.storage.InMemorySecureStorage] and
 * Android's `TinkSecureStorage`), so typed accessors round-trip identically
 * across platforms.
 *
 * Accessibility: [kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly] —
 *  - *AfterFirstUnlock*: readable by background work once the device has been
 *    unlocked once since boot (this app runs background location/services).
 *  - *ThisDeviceOnly*: never migrated to a new device or iCloud Keychain
 *    backup — mirrors the device-bound Android Keystore master key.
 *
 * Fail-safe contract (identical to Android): operations never throw. Reads
 * return null on miss ([errSecItemNotFound]) or failure; writes log + report
 * and swallow. See [StorageEvent].
 */
internal class KeychainSecureStorage(
    private val service: String,
    private val logger: Logger,
    private val crashReporter: CrashReporter,
    private val dispatchers: AppDispatchers,
) : SecureStorage {

    // ── typed accessors (serialize through String, like Android) ──

    override suspend fun getString(key: String): String? = read(key)

    override suspend fun putString(key: String, value: String) = write(key, value)

    override suspend fun getInt(key: String): Int? = readTyped(key) { it.toIntOrNull() }

    override suspend fun putInt(key: String, value: Int) = write(key, value.toString())

    override suspend fun getLong(key: String): Long? = readTyped(key) { it.toLongOrNull() }

    override suspend fun putLong(key: String, value: Long) = write(key, value.toString())

    override suspend fun getBool(key: String): Boolean? = readTyped(key) { it.toBooleanStrictOrNull() }

    override suspend fun putBool(key: String, value: Boolean) = write(key, value.toString())

    override suspend fun getDouble(key: String): Double? = readTyped(key) { it.toDoubleOrNull() }

    override suspend fun putDouble(key: String, value: Double) = write(key, value.toString())

    // ── read / write / delete ──

    private suspend fun read(key: String): String? = withContext(dispatchers.io) {
        try {
            memScoped {
                val out = alloc<CFTypeRefVar>()
                val status = keychainQuery(
                    account = key,
                    kSecReturnData to kCFBooleanTrue,
                    kSecMatchLimit to kSecMatchLimitOne,
                ) { query -> SecItemCopyMatching(query, out.ptr) }

                when (status) {
                    errSecSuccess -> (CFBridgingRelease(out.value) as? NSData)?.decodeToString()
                    errSecItemNotFound -> null
                    else -> {
                        logReadFailure(key, status)
                        null
                    }
                }
            }
        } catch (e: Exception) {
            logger.e(TAG, "${StorageEvent.STORAGE_READ_FAILED}: key=$key", e)
            crashReporter.report(e, mapOf("op" to "secureStorage.read", "key" to key))
            null
        }
    }

    // Reads [key] then parses via [parse]. A present-but-unparseable value means a different type
    // was stored under this key: emit STORAGE_TYPE_MISMATCH so it's distinguishable from an absent
    // key (mirrors Android's TinkSecureStorage.decryptTyped).
    private suspend fun <T> readTyped(key: String, parse: (String) -> T?): T? {
        val raw = read(key) ?: return null
        return parse(raw) ?: run {
            logger.e(TAG, "${StorageEvent.STORAGE_TYPE_MISMATCH}: key=$key")
            null
        }
    }

    /** @return true if the value was stored. */
    private suspend fun write(key: String, value: String): Boolean = withContext(dispatchers.io) {
        try {
            // Upsert = add-first, update-on-duplicate. Never delete up front: a delete-then-add drops
            // the secret if the add fails or the process dies between the two, so a failed/racy write
            // must leave any existing value intact (mirrors the Android/Tink transactional overwrite,
            // which retains ciphertext on failure).
            val data = value.encodeToNSData() ?: return@withContext false
            val dataRef = CFBridgingRetain(data)
            try {
                val status = keychainQuery(
                    account = key,
                    kSecValueData to dataRef,
                    kSecAttrAccessible to kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
                ) { query -> SecItemAdd(query, null) }
                when (status) {
                    errSecSuccess -> true
                    // Already present — the add left the old value untouched; update it in place.
                    errSecDuplicateItem -> {
                        val updateStatus = updateItemData(key, dataRef)
                        if (updateStatus == errSecSuccess) {
                            true
                        } else {
                            logWriteFailure(key, updateStatus)
                            false
                        }
                    }
                    else -> {
                        logWriteFailure(key, status)
                        false
                    }
                }
            } finally {
                dataRef?.let { CFBridgingRelease(it) }
            }
        } catch (e: Exception) {
            logger.e(TAG, "${StorageEvent.STORAGE_WRITE_FAILED}: key=$key", e)
            crashReporter.report(e, mapOf("op" to "secureStorage.write", "key" to key))
            false
        }
    }

    override suspend fun remove(key: String): Boolean = withContext(dispatchers.io) {
        try {
            val status = deleteItem(key)
            status == errSecSuccess || status == errSecItemNotFound
        } catch (e: Exception) {
            logger.e(TAG, "${StorageEvent.STORAGE_WRITE_FAILED}: remove key=$key", e)
            crashReporter.report(e, mapOf("op" to "secureStorage.remove", "key" to key))
            false
        }
    }

    override suspend fun clear(): Boolean = withContext(dispatchers.io) {
        try {
            // No account → matches every item under this service.
            val status = keychainQuery(account = null) { query -> SecItemDelete(query) }
            if (status == errSecSuccess || status == errSecItemNotFound) {
                true
            } else {
                logWriteFailure(key = "*", status = status)
                false
            }
        } catch (e: Exception) {
            logger.e(TAG, "${StorageEvent.STORAGE_WRITE_FAILED}: clear", e)
            crashReporter.report(e, mapOf("op" to "secureStorage.clear"))
            false
        }
    }

    /** Deletes one item; [errSecItemNotFound] is a no-op success. */
    private fun deleteItem(key: String): OSStatus =
        keychainQuery(account = key) { query -> SecItemDelete(query) }

    /**
     * Updates an existing item's stored bytes (the [errSecDuplicateItem] branch of [write]). The base
     * query (`class` + `service` + `account`) identifies the item; the attributes dictionary carries
     * the new [dataRef]. [dataRef] is owned by the caller ([write] releases it); the attributes
     * dictionary is created and released here.
     */
    private fun updateItemData(key: String, dataRef: CFTypeRef?): OSStatus {
        val attributes = cfDictionaryOf(listOf(kSecValueData to dataRef))
        return try {
            keychainQuery(account = key) { query -> SecItemUpdate(query, attributes) }
        } finally {
            attributes?.let { CFRelease(it) }
        }
    }

    // ── Keychain query plumbing ──

    /**
     * Builds the base query (`class` + `service` [+ `account`]) plus [extra]
     * attributes, runs [operation], and releases every CoreFoundation object
     * it owns. Bridged values passed in [extra] (e.g. `kSecValueData`) are
     * owned by the caller and released by the caller.
     */
    private fun keychainQuery(
        account: String?,
        vararg extra: Pair<CFStringRef?, CFTypeRef?>,
        operation: (CFDictionaryRef?) -> OSStatus,
    ): OSStatus {
        val serviceRef = CFBridgingRetain(service.toNSString())
        val accountRef = account?.let { CFBridgingRetain(it.toNSString()) }
        val pairs = buildList<Pair<CFStringRef?, CFTypeRef?>> {
            add(kSecClass to kSecClassGenericPassword)
            add(kSecAttrService to serviceRef)
            if (accountRef != null) add(kSecAttrAccount to accountRef)
            addAll(extra)
        }
        val query = cfDictionaryOf(pairs)
        return try {
            operation(query)
        } finally {
            query?.let { CFRelease(it) }
            serviceRef?.let { CFBridgingRelease(it) }
            accountRef?.let { CFBridgingRelease(it) }
        }
    }

    private fun logReadFailure(key: String, status: OSStatus) {
        logger.e(TAG, "${StorageEvent.STORAGE_READ_FAILED}: key=$key osstatus=$status")
        crashReporter.report(
            KeychainException("read failed", status),
            mapOf("op" to "secureStorage.read", "key" to key, "osstatus" to status.toString()),
        )
    }

    private fun logWriteFailure(key: String, status: OSStatus) {
        logger.e(TAG, "${StorageEvent.STORAGE_WRITE_FAILED}: key=$key osstatus=$status")
        crashReporter.report(
            KeychainException("write failed", status),
            mapOf("op" to "secureStorage.write", "key" to key, "osstatus" to status.toString()),
        )
    }

    internal companion object {
        const val TAG = "KeychainSecureStorage"
    }
}

private class KeychainException(message: String, status: OSStatus) :
    Exception("$message (OSStatus=$status)")

// ── CoreFoundation / Foundation helpers ──

private fun String.toNSString(): NSString = this as NSString

private fun String.encodeToNSData(): NSData? =
    (this as NSString).dataUsingEncoding(NSUTF8StringEncoding)

private fun NSData.decodeToString(): String? =
    NSString.create(data = this, encoding = NSUTF8StringEncoding) as String?

/**
 * Creates an immutable `CFDictionary` from [pairs]. Keys use CF string
 * callbacks and values use CF type callbacks, so the dictionary retains its
 * values for its own lifetime (released when the dictionary is released).
 */
private fun cfDictionaryOf(pairs: List<Pair<CFStringRef?, CFTypeRef?>>): CFDictionaryRef? =
    memScoped {
        val keys = allocArrayOfPointers(pairs.map { it.first })
        val values = allocArrayOfPointers(pairs.map { it.second })
        CFDictionaryCreate(
            kCFAllocatorDefault,
            keys,
            values,
            pairs.size.convert(),
            kCFTypeDictionaryKeyCallBacks.ptr,
            kCFTypeDictionaryValueCallBacks.ptr,
        )
    }

private fun NativePlacement.allocArrayOfPointers(
    elements: List<CFTypeRef?>,
): CArrayPointer<COpaquePointerVar> {
    val array = allocArray<COpaquePointerVar>(elements.size)
    elements.forEachIndexed { index, element -> array[index] = element }
    return array
}
