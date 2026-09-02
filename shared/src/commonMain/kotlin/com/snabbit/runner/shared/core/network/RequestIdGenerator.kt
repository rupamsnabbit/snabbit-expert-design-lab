package com.snabbit.runner.shared.core.network

import com.snabbit.runner.shared.core.NowIso

/**
 * SHA-1 of `bytes`. Platform-specific because there is no portable
 * commonMain crypto primitive yet (Android: java.security.MessageDigest;
 * future iOS: CommonCrypto). See §8.2.
 */
internal expect fun sha1(bytes: ByteArray): ByteArray

/**
 * Generates the `X-Request-ID` header value (§8). Produces a UUID-v5-shaped
 * identifier that mirrors the Dart `UuidGenerator` algorithm so request IDs
 * on the Kotlin and Dart sides follow the same pattern:
 *
 *  - namespace = UTF-8 bytes of [baseUrl] (NOT a real namespace UUID — this
 *    diverges from RFC 4122 but matches the existing Dart implementation).
 *  - name      = "${method}-${timestamp}"
 *  - hash      = SHA-1(namespace || name)
 *  - patch v5 + RFC-4122 variant bits, then format 8-4-4-4-12.
 *
 * [nowIso] is injectable so tests can pin the timestamp for parity checks.
 */
class RequestIdGenerator(
    private val nowIso: NowIso,
) {
    fun generate(method: String, baseUrl: String): String {
        val name = "$method-${nowIso()}"
        val namespaceBytes = baseUrl.encodeToByteArray()
        val nameBytes = name.encodeToByteArray()
        val hash = sha1(namespaceBytes + nameBytes).copyOf()

        hash[6] = ((hash[6].toInt() and 0x0f) or 0x50).toByte()        // version = 5
        hash[8] = ((hash[8].toInt() and 0x3f) or 0x80).toByte()        // RFC 4122 variant

        return buildString(36) {
            appendHex(hash, 0, 4); append('-')
            appendHex(hash, 4, 6); append('-')
            appendHex(hash, 6, 8); append('-')
            appendHex(hash, 8, 10); append('-')
            appendHex(hash, 10, 16)
        }
    }

    private fun StringBuilder.appendHex(src: ByteArray, from: Int, untilExclusive: Int) {
        for (i in from until untilExclusive) {
            val v = src[i].toInt() and 0xff
            append(HEX[v ushr 4])
            append(HEX[v and 0x0f])
        }
    }

    private companion object {
        val HEX = "0123456789abcdef".toCharArray()
    }
}
