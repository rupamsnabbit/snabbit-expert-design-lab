package com.snabbit.runner.shared.core.network

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotEquals
import kotlin.test.assertTrue

class RequestIdGeneratorTest {

    /**
     * Parity fixture: for namespace = "https://test.snabbit.com/" and
     * name = "GET-2026-05-12T10:30:45.123", SHA-1 of (namespace || name)
     * is 9b4ff60236d4fabaefabd3b57854517d79d7ff4d (verified with shasum).
     *
     * After version-5 (byte 6) and RFC-4122 variant (byte 8) patching:
     *  - byte 6: 0xfa & 0x0f | 0x50 = 0x5a
     *  - byte 8: 0xef & 0x3f | 0x80 = 0xaf
     *
     * Formatted 8-4-4-4-12 gives the expected UUID below.
     */
    @Test
    fun generate_producesExpectedV5_forKnownInput() {
        val gen = RequestIdGenerator(nowIso = { "2026-05-12T10:30:45.123" })
        val id = gen.generate(method = "GET", baseUrl = "https://test.snabbit.com/")
        assertEquals("9b4ff602-36d4-5aba-afab-d3b57854517d", id)
    }

    @Test
    fun generate_hasUuidShape() {
        val gen = RequestIdGenerator(nowIso = { "2026-05-12T10:30:45.123" })
        val id = gen.generate("POST", "https://test.snabbit.com/")
        // 36 chars, hyphens at positions 8/13/18/23.
        assertEquals(36, id.length)
        assertEquals('-', id[8])
        assertEquals('-', id[13])
        assertEquals('-', id[18])
        assertEquals('-', id[23])
        // Version nibble is '5'.
        assertEquals('5', id[14])
        // Variant nibble is 8, 9, a, or b.
        assertTrue(id[19] in "89ab", "variant nibble should be 8/9/a/b, got ${id[19]}")
        // Hex everywhere else.
        assertTrue(id.replace("-", "").all { it in "0123456789abcdef" })
    }

    @Test
    fun generate_isDeterministic_forSameInputs() {
        val gen = RequestIdGenerator(nowIso = { "2026-05-12T10:30:45.123" })
        val a = gen.generate("GET", "https://example.com/")
        val b = gen.generate("GET", "https://example.com/")
        assertEquals(a, b)
    }

    @Test
    fun generate_differs_forDifferentMethods() {
        val gen = RequestIdGenerator(nowIso = { "2026-05-12T10:30:45.123" })
        val get = gen.generate("GET", "https://example.com/")
        val post = gen.generate("POST", "https://example.com/")
        assertNotEquals(get, post)
    }

    @Test
    fun generate_differs_forDifferentBaseUrls() {
        val gen = RequestIdGenerator(nowIso = { "2026-05-12T10:30:45.123" })
        val a = gen.generate("GET", "https://a.example.com/")
        val b = gen.generate("GET", "https://b.example.com/")
        assertNotEquals(a, b)
    }

    @Test
    fun generate_differs_forDifferentTimestamps() {
        var ts = "2026-05-12T10:30:45.123"
        val gen = RequestIdGenerator(nowIso = { ts })
        val a = gen.generate("GET", "https://example.com/")
        ts = "2026-05-12T10:30:45.124"
        val b = gen.generate("GET", "https://example.com/")
        assertNotEquals(a, b)
    }
}
