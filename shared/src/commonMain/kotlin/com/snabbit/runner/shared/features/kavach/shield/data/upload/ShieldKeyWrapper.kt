package com.snabbit.runner.shared.features.kavach.shield.data.upload

import dev.whyoleg.cryptography.CryptographyProvider
import dev.whyoleg.cryptography.algorithms.RSA
import dev.whyoleg.cryptography.algorithms.SHA256
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlin.io.encoding.Base64
import kotlin.io.encoding.ExperimentalEncodingApi

/**
 * RSA-OAEP-256 key-wrap (Step 7.2) — 1:1 with the Flutter `ShieldEncryptor.wrapAesKey`:
 * base64-decode the plugin's AES key → RSA-OAEP (SHA-256 hash + MGF1-SHA-256) encrypt with the
 * server's SPKI public key → base64-encode. The key material becomes `encryption.encrypted_key`
 * in the upload envelope.
 *
 * The public key is loaded once from [pemProvider] (bundled SPKI PEM) and cached; Android uses the
 * JDK provider, iOS the Apple Security.framework provider (CryptoKit has no RSA).
 */
class ShieldKeyWrapper(
    private val pemProvider: suspend () -> ByteArray,
) {
    private val mutex = Mutex()
    private var cached: RSA.OAEP.PublicKey? = null

    @OptIn(ExperimentalEncodingApi::class)
    suspend fun wrapAesKey(aesSecretKeyBase64: String): String {
        val aesKeyBytes = Base64.decode(aesSecretKeyBase64)
        val wrapped = publicKey().encryptor().encrypt(aesKeyBytes)
        return Base64.encode(wrapped)
    }

    private suspend fun publicKey(): RSA.OAEP.PublicKey {
        cached?.let { return it }
        return mutex.withLock {
            cached ?: CryptographyProvider.Default
                .get(RSA.OAEP)
                .publicKeyDecoder(SHA256)
                .decodeFromByteArray(RSA.PublicKey.Format.PEM.Generic, pemProvider())
                .also { cached = it }
        }
    }
}
