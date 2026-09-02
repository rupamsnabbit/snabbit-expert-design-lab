package com.snabbit.runner.shared.core.location

import kotlin.math.abs
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class DistanceTest {

    // 0.01° of latitude at any longitude ≈ 1112.5 m (great-circle, IUGG mean R).
    // Synthetic so the expectation is derived from the formula's own constants,
    // not from an external map tool whose snapshots drift.
    @Test fun haversine_oneCentidegreeLatitude_isAbout1112m() {
        val d = distanceMeters(startLatitude = 0.0, startLongitude = 0.0, endLatitude = 0.01, endLongitude = 0.0)
        // Within 1 m of the analytic value (R · π/180 · 0.01 = 1112.4).
        assertTrue(abs(d - 1112.4) < 1.0, "expected ~1112m, was $d")
    }

    @Test fun haversine_identityIsZero() {
        val d = distanceMeters(12.9716, 77.5946, 12.9716, 77.5946)
        assertEquals(0.0, d, 1e-6)
    }

    @Test fun haversine_isSymmetric() {
        val a = distanceMeters(12.9716, 77.5946, 12.9352, 77.6245)
        val b = distanceMeters(12.9352, 77.6245, 12.9716, 77.5946)
        assertEquals(a, b, 1e-6)
    }

    @Test fun format_subKilometer_rendersIntegerMeters() {
        assertEquals("300 m", formatDistance(300.0))
        assertEquals("1 m", formatDistance(0.7))
        assertEquals("999 m", formatDistance(999.4))
    }

    @Test fun format_kilometers_rendersOneDecimal() {
        assertEquals("1.0 km", formatDistance(1000.0))
        assertEquals("3.2 km", formatDistance(3215.0))
        assertEquals("12.5 km", formatDistance(12_500.0))
    }

    /** Regression: values in [999.5, 1000) rounded up to "1000 m" because the
     *  unit was chosen before rounding. They should cross into "1.0 km". */
    @Test fun format_justUnderOneKm_roundsIntoKilometers() {
        assertEquals("1.0 km", formatDistance(999.5))
        assertEquals("1.0 km", formatDistance(999.9))
        assertEquals("999 m", formatDistance(999.49))
    }
}
