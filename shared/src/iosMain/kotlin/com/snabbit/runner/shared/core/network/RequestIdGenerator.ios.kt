package com.snabbit.runner.shared.core.network

import kotlinx.cinterop.ExperimentalForeignApi
import kotlinx.cinterop.addressOf
import kotlinx.cinterop.convert
import kotlinx.cinterop.usePinned
import platform.CoreCrypto.CC_SHA1
import platform.CoreCrypto.CC_SHA1_DIGEST_LENGTH

/**
 * SHA-1 via Apple's native CommonCrypto (`CC_SHA1`) — the iOS-native crypto, with commonMain as the
 * consumer through the `sha1` expect/actual. Mirrors the Android `MessageDigest("SHA-1")` actual
 * byte-for-byte (standard SHA-1). This is a deterministic request-id hash, not a security digest —
 * CryptoKit is Swift-only (unreachable from K/N), so CommonCrypto is the compatible native path.
 * [bytes] is always non-empty here (namespace ‖ name).
 */
@OptIn(ExperimentalForeignApi::class)
internal actual fun sha1(bytes: ByteArray): ByteArray {
    val digest = UByteArray(CC_SHA1_DIGEST_LENGTH.toInt())
    bytes.usePinned { input ->
        digest.usePinned { output ->
            CC_SHA1(input.addressOf(0), bytes.size.convert(), output.addressOf(0))
        }
    }
    return digest.toByteArray()
}
