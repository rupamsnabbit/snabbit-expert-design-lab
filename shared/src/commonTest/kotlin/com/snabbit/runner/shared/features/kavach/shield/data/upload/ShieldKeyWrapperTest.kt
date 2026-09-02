package com.snabbit.runner.shared.features.kavach.shield.data.upload

import kotlinx.coroutines.test.runTest
import kotlin.io.encoding.Base64
import kotlin.io.encoding.ExperimentalEncodingApi
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * Verifies the RSA-OAEP-256 wrap runs end-to-end against a real SPKI public key: correct RSA-2048
 * block size out, and real OAEP randomization (two wraps of the same key differ). The throwaway
 * key below is generated for this test only — not the production key.
 */
@OptIn(ExperimentalEncodingApi::class)
class ShieldKeyWrapperTest {

    // Throwaway RSA-2048 SPKI public key (test-only).
    private val testPem = """
        -----BEGIN PUBLIC KEY-----
        MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAvRf7oFqMsqqAgWIUr01P
        vVj9vBlaEaq2vsErNTZXHepVXZzBJfSlHih5LblNBgdbZLEE9YXt9rS0JZx3FNme
        Esi4qKqjipdWn2nTWujf2lllkDLt+9dehrajPHrzU7lVPs8ct52af3VE665NrJpI
        uWfA32OfTx2Jq7NfeEtvT81L/1K3t67oIwU36jtvUtAkPz8GptuBnR2koEYXu74I
        eANc+jxDC+5Jo6pKjk3ac1rwigY4vc6eX5o6guj+ZkPLV36V32FLS7rB3FbpBCAh
        XTEGcM/8PmJUj4Lw+/kNFMcjIpxGsaIHLSKricBMes3K/W1CZgLi2XCyeD5+S9L5
        pwIDAQAB
        -----END PUBLIC KEY-----
    """.trimIndent()

    private fun wrapper() = ShieldKeyWrapper { testPem.encodeToByteArray() }

    @Test
    fun wrapAesKey_producesRsa2048Block() = runTest {
        val aesKeyB64 = Base64.encode(ByteArray(32) { it.toByte() })   // 256-bit AES key
        val out = wrapper().wrapAesKey(aesKeyB64)
        assertTrue(out.isNotBlank())
        assertEquals(256, Base64.decode(out).size)   // RSA-2048 ciphertext = 256 bytes
    }

    @Test
    fun wrapAesKey_isRandomized_notDeterministic() = runTest {
        val w = wrapper()
        val aesKeyB64 = Base64.encode(ByteArray(32) { 7 })
        val a = w.wrapAesKey(aesKeyB64)
        val b = w.wrapAesKey(aesKeyB64)
        assertTrue(a != b, "OAEP padding must randomize each wrap")
    }
}
