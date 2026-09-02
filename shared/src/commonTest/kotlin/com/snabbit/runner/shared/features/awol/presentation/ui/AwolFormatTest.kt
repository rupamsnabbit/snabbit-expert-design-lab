package com.snabbit.runner.shared.features.awol.presentation.ui

import kotlin.test.Test
import kotlin.test.assertEquals

class AwolFormatTest {

    @Test
    fun formatsMmSs() {
        assertEquals("15:23", formatAwolMmSs(923))
        assertEquals("00:00", formatAwolMmSs(0))
        assertEquals("00:09", formatAwolMmSs(9))
        assertEquals("01:00", formatAwolMmSs(60))
    }

    @Test
    fun negativeClampsToZero() {
        assertEquals("00:00", formatAwolMmSs(-5))
    }

    @Test
    fun overAnHour_keepsMinutes() {
        assertEquals("90:00", formatAwolMmSs(5400))
    }

    @Test
    fun distanceUnderAKilometre_isWholeMetres() {
        assertEquals("0m away", formatAwolDistance(0.0, "away"))
        assertEquals("850m away", formatAwolDistance(850.0, "away"))
        assertEquals("999m away", formatAwolDistance(999.0, "away"))
    }

    @Test
    fun distanceFromAKilometre_isOneDecimalKm() {
        assertEquals("1.0 km away", formatAwolDistance(1000.0, "away"))
        assertEquals("3.2 km away", formatAwolDistance(3210.0, "away"))
    }

    @Test
    fun distanceRounding_matchesToStringAsFixed() {
        // 999.5 rounds within the metre branch; 1049 → "1.0", 1050 → "1.1" —
        // the same half-up behaviour Dart's toStringAsFixed(1) shows.
        assertEquals("1000m away", formatAwolDistance(999.5, "away"))
        assertEquals("1.0 km away", formatAwolDistance(1049.0, "away"))
        assertEquals("1.1 km away", formatAwolDistance(1050.0, "away"))
    }

    @Test
    fun distanceSuffix_isCallerSupplied() {
        assertEquals("850m dur", formatAwolDistance(850.0, "dur"))
    }
}
