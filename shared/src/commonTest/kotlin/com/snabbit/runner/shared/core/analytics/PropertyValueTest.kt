package com.snabbit.runner.shared.core.analytics

import com.snabbit.runner.shared.core.FakeLogger
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class PropertyValueTest {

    private val logger = FakeLogger()

    @Test
    fun emptyMap_returnsEmpty() {
        assertTrue(PropertyValue.sanitize(emptyMap(), logger).isEmpty())
    }

    @Test
    fun stripsNulls() {
        val out = PropertyValue.sanitize(
            mapOf("a" to "x", "b" to null, "c" to 1),
            logger,
        )
        assertEquals(mapOf("a" to "x", "c" to 1L), out)
        assertFalse(out.containsKey("b"))
    }

    @Test
    fun widensIntToLong() {
        val out = PropertyValue.sanitize(mapOf("count" to 42), logger)
        assertEquals(42L, out["count"])
        assertTrue(out["count"] is Long)
    }

    @Test
    fun widensShortAndByteToLong() {
        val out = PropertyValue.sanitize(
            mapOf("s" to 7.toShort(), "b" to 9.toByte()),
            logger,
        )
        assertEquals(7L, out["s"])
        assertEquals(9L, out["b"])
    }

    @Test
    fun widensFloatToDouble() {
        val out = PropertyValue.sanitize(mapOf("ratio" to 1.5f), logger)
        assertEquals(1.5, out["ratio"])
        assertTrue(out["ratio"] is Double)
    }

    @Test
    fun keepsLongDoubleStringBooleanAsIs() {
        val out = PropertyValue.sanitize(
            mapOf(
                "l" to 100L,
                "d" to 2.5,
                "s" to "hello",
                "bo" to true,
            ),
            logger,
        )
        assertEquals(100L, out["l"])
        assertEquals(2.5, out["d"])
        assertEquals("hello", out["s"])
        assertEquals(true, out["bo"])
    }

    @Test
    fun coercesCharToString() {
        val out = PropertyValue.sanitize(mapOf("c" to 'A'), logger)
        assertEquals("A", out["c"])
    }

    @Test
    fun truncatesLongStrings() {
        val long = "x".repeat(2000)
        val out = PropertyValue.sanitize(mapOf("s" to long), logger)
        assertEquals(1024, (out["s"] as String).length)
        assertTrue(logger.entries.any { it.level == FakeLogger.Level.WARN && it.message.contains("truncated") })
    }

    @Test
    fun unsupportedTypeFallsBackToToString() {
        data class Sentinel(val v: Int) { override fun toString() = "Sentinel($v)" }
        val out = PropertyValue.sanitize(mapOf("k" to Sentinel(3)), logger)
        assertEquals("Sentinel(3)", out["k"])
        assertTrue(logger.entries.any { it.level == FakeLogger.Level.WARN && it.message.contains("toString()") })
    }

    @Test
    fun isIdempotent() {
        val once = PropertyValue.sanitize(
            mapOf("i" to 1, "f" to 1.5f, "s" to "ok", "n" to null),
            logger,
        )
        val twice = PropertyValue.sanitize(once, logger)
        assertEquals(once, twice)
    }
}
