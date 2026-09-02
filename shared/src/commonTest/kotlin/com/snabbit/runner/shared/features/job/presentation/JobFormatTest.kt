package com.snabbit.runner.shared.features.job.presentation

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class JobFormatTest {

    @Test
    fun rupees_formatsAmountOrZero() {
        assertEquals("₹150", formatRupees(150))
        assertEquals("₹0", formatRupees(null))
        assertEquals("₹0", formatRupees(0))
    }

    @Test
    fun mmSs_formatsAndClampsNegatives() {
        assertEquals("1:23", formatMmSs(83))
        assertEquals("0:05", formatMmSs(5))
        assertEquals("2:00", formatMmSs(120))
        assertEquals("0:00", formatMmSs(-1))
    }

    @Test
    fun isoClockTime_rendersIst_offsetAware() {
        // IST-offset payloads render their own wall-clock (identity).
        assertEquals("7:45 PM", formatIsoClockTime("2026-06-27T19:45:00+05:30"))
        assertEquals("12:30 AM", formatIsoClockTime("2026-06-27T00:30:00+05:30"))
        assertEquals("9:05 AM", formatIsoClockTime("2026-06-27T09:05:00+05:30"))
        // A UTC payload is converted to IST (+5:30): 14:15 UTC == 19:45 IST — same instant, same label.
        assertEquals("7:45 PM", formatIsoClockTime("2026-06-27T14:15:00Z"))
        assertEquals("5:30 PM", formatIsoClockTime("2026-06-27T12:00:00Z"))
        // UTC → IST across midnight rolls the clock: 20:00Z == 01:30 IST.
        assertEquals("1:30 AM", formatIsoClockTime("2026-06-27T20:00:00Z"))
        // Colon-less offset + fractional seconds are handled.
        assertEquals("7:45 PM", formatIsoClockTime("2026-06-27T19:45:00+0530"))
        assertEquals("7:45 PM", formatIsoClockTime("2026-06-27T14:15:00.123Z"))
        // No zone → assumed already IST (unchanged).
        assertEquals("9:05 AM", formatIsoClockTime("2026-06-27T09:05:00"))
    }

    @Test
    fun isoClockTime_nullOrMalformed_isNull() {
        assertNull(formatIsoClockTime(null))
        assertNull(formatIsoClockTime("garbage"))
        assertNull(formatIsoClockTime("2026-06-27"))
    }
}
