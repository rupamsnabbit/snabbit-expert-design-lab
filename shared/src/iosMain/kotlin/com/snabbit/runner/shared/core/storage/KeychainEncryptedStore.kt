package com.snabbit.runner.shared.core.storage

import kotlinx.cinterop.ExperimentalForeignApi
import kotlinx.cinterop.addressOf
import kotlinx.cinterop.alloc
import kotlinx.cinterop.convert
import kotlinx.cinterop.memScoped
import kotlinx.cinterop.ptr
import kotlinx.cinterop.reinterpret
import kotlinx.cinterop.usePinned
import kotlinx.cinterop.value
import platform.CoreFoundation.CFDataCreate
import platform.CoreFoundation.CFDataGetBytePtr
import platform.CoreFoundation.CFDataGetLength
import platform.CoreFoundation.CFDataRef
import platform.CoreFoundation.CFDictionaryAddValue
import platform.CoreFoundation.CFDictionaryCreateMutable
import platform.CoreFoundation.CFDictionaryRef
import platform.CoreFoundation.CFMutableDictionaryRef
import platform.CoreFoundation.CFRelease
import platform.CoreFoundation.CFStringCreateWithCString
import platform.CoreFoundation.CFStringRef
import platform.CoreFoundation.CFTypeRefVar
import platform.CoreFoundation.kCFBooleanTrue
import platform.CoreFoundation.kCFStringEncodingUTF8
import platform.CoreFoundation.kCFTypeDictionaryKeyCallBacks
import platform.CoreFoundation.kCFTypeDictionaryValueCallBacks
import platform.Security.SecItemAdd
import platform.Security.SecItemCopyMatching
import platform.Security.SecItemDelete
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
import platform.posix.memcpy

/**
 * iOS Keychain-backed [EncryptedStore] (generic-password items, service-scoped) via native
 * Security.framework `SecItem*`. Secure at rest by the OS. `putString` is an upsert (delete → add).
 * commonTest can't exercise this (Keychain needs an app + entitlements) — it is the production
 * iOS actual, compile-verified here; real behaviour is on-device.
 */
@OptIn(ExperimentalForeignApi::class)
internal class KeychainEncryptedStore(private val service: String) : EncryptedStore {

    override suspend fun getString(key: String): String? = memScoped {
        val query = query(key) { d ->
            CFDictionaryAddValue(d, kSecReturnData, kCFBooleanTrue)
            CFDictionaryAddValue(d, kSecMatchLimit, kSecMatchLimitOne)
        }
        val out = alloc<CFTypeRefVar>()
        val status = SecItemCopyMatching(query, out.ptr)
        CFRelease(query)
        if (status != errSecSuccess) return@memScoped null
        val cfData = out.value ?: return@memScoped null
        val bytes = cfDataToByteArray(cfData.reinterpret())
        CFRelease(cfData)
        bytes.decodeToString()
    }

    override suspend fun putString(key: String, value: String) {
        delete(key)
        val raw = value.encodeToByteArray()
        val cfData = raw.usePinned {
            if (raw.isEmpty()) CFDataCreate(null, null, 0)
            else CFDataCreate(null, it.addressOf(0).reinterpret(), raw.size.convert())
        }
        // Readable after first unlock (even while locked) so background SOS/uploads can read the auth
        // token — else SecItemCopyMatching returns errSecInteractionNotAllowed → null → the request
        // goes out unauthenticated. ThisDevice = not iCloud-synced / not in backups (#12).
        val query = query(key) { d ->
            CFDictionaryAddValue(d, kSecValueData, cfData)
            CFDictionaryAddValue(d, kSecAttrAccessible, kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly)
        }
        val status = SecItemAdd(query, null)
        CFRelease(query)
        cfData?.let { CFRelease(it) }
        // Surface a failed Keychain write (after CFRelease, so no CF object leaks) so
        // StoreManagerImpl's optimistic-update rollback fires — parity with the Android DataStore
        // actual, which throws on a failed write (#kc).
        if (status != errSecSuccess) error("Keychain SecItemAdd failed: $status")
    }

    override suspend fun delete(key: String) {
        val query = query(key) {}
        val status = SecItemDelete(query)
        CFRelease(query)
        // errSecItemNotFound is fine — delete is idempotent (matches Android's remove-absent no-op).
        if (status != errSecSuccess && status != errSecItemNotFound) error("Keychain SecItemDelete failed: $status")
    }

    override suspend fun getAll(keys: Set<String>): Map<String, String> =
        keys.mapNotNull { k -> getString(k)?.let { k to it } }.toMap()

    private inline fun query(key: String, extra: (CFMutableDictionaryRef?) -> Unit): CFDictionaryRef {
        val dict = CFDictionaryCreateMutable(null, 0, kCFTypeDictionaryKeyCallBacks.ptr, kCFTypeDictionaryValueCallBacks.ptr)
        CFDictionaryAddValue(dict, kSecClass, kSecClassGenericPassword)
        val svc = service.toCFString()
        val acct = key.toCFString()
        CFDictionaryAddValue(dict, kSecAttrService, svc)
        CFDictionaryAddValue(dict, kSecAttrAccount, acct)
        extra(dict)
        svc?.let { CFRelease(it) }
        acct?.let { CFRelease(it) }
        return dict!!
    }

    private fun String.toCFString(): CFStringRef? =
        CFStringCreateWithCString(null, this, kCFStringEncodingUTF8)

    private fun cfDataToByteArray(data: CFDataRef?): ByteArray {
        data ?: return ByteArray(0)
        val len = CFDataGetLength(data).toInt()
        if (len <= 0) return ByteArray(0)
        val src = CFDataGetBytePtr(data) ?: return ByteArray(0)
        val out = ByteArray(len)
        out.usePinned { memcpy(it.addressOf(0), src, len.convert()) }
        return out
    }
}
