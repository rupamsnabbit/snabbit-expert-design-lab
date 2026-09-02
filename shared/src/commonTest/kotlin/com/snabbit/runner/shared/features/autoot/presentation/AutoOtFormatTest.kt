package com.snabbit.runner.shared.features.autoot.presentation

import kotlin.test.Test
import kotlin.test.assertEquals

class AutoOtFormatTest {

    @Test
    fun timeRange_formatsAndStripsWholeHourMinutes() {
        assertEquals(
            "8 AM - 7 PM",
            formatTimeRange("2026-02-07T08:00:00+05:30", "2026-02-07T19:00:00+05:30"),
        )
        assertEquals(
            "8 AM - 5 PM",
            formatTimeRange("2026-02-07T08:00:00+05:30", "2026-02-07T17:00:00+05:30"),
        )
        // whole-hour noon collapses to "12 PM"
        assertEquals(
            "8 AM - 12 PM",
            formatTimeRange("2026-02-07T08:00:00+05:30", "2026-02-07T12:00:00+05:30"),
        )
    }

    @Test
    fun timeRange_keepsNonZeroMinutes() {
        assertEquals(
            "7:45 AM - 12:30 PM",
            formatTimeRange("2026-02-07T07:45:00+05:30", "2026-02-07T12:30:00+05:30"),
        )
    }

    @Test
    fun timeRange_nullOrMalformed_isEmpty() {
        assertEquals("", formatTimeRange(null, "2026-02-07T19:00:00+05:30"))
        assertEquals("", formatTimeRange("2026-02-07T08:00:00+05:30", null))
        assertEquals("", formatTimeRange("garbage", "2026-02-07T19:00:00+05:30"))
        assertEquals("", formatTimeRange(null, null))
    }

    @Test
    fun rupees_indianGroupingWithSymbol() {
        assertEquals("₹750", formatOtRupees(750))
        assertEquals("₹600", formatOtRupees(600))
        assertEquals("₹0", formatOtRupees(0))
        assertEquals("₹1,750", formatOtRupees(1750))
        assertEquals("₹12,34,567", formatOtRupees(1234567))
    }

    @Test
    fun rupees_nullIsEmpty() {
        assertEquals("", formatOtRupees(null))
    }
}
