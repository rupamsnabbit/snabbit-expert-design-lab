package com.snabbit.runner.shared.core.location

import kotlin.math.abs
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class GeoDistanceTest {

    @Test
    fun identicalPoints_returnZero() {
        assertEquals(0.0, distanceMeters(12.91, 77.64, 12.91, 77.64))
    }

    @Test
    fun knownCityPair_matchesGeodesicDistanceWithinTolerance() {
        // Bengaluru (12.9716, 77.5946) → Mumbai (19.0760, 72.8777) ≈ 845 km
        // great-circle. Haversine on the equatorial radius lands within ~0.5%.
        val meters = distanceMeters(12.9716, 77.5946, 19.0760, 72.8777)
        assertTrue(abs(meters - 845_000) < 5_000, "expected ~845 km, got $meters m")
    }

    @Test
    fun shortHop_isMetreAccurate() {
        // ~111.32 m per 0.001° of latitude at the equator (radius-scaled).
        val meters = distanceMeters(0.0, 0.0, 0.001, 0.0)
        assertTrue(abs(meters - 111.32) < 0.5, "expected ~111.3 m, got $meters m")
    }

    @Test
    fun distance_isSymmetric() {
        val forward = distanceMeters(12.91, 77.64, 12.935, 77.61)
        val back = distanceMeters(12.935, 77.61, 12.91, 77.64)
        assertEquals(forward, back)
    }

    @Test
    fun antipodes_doNotOverflowTheAsinDomain() {
        // Floating-point drift can push the haversine term past 1.0 here; the
        // clamp keeps the result a finite half-circumference, never NaN.
        val meters = distanceMeters(0.0, 0.0, 0.0, 180.0)
        assertTrue(meters.isFinite())
        assertTrue(abs(meters - 20_037_508) < 10_000, "expected ~half circumference, got $meters m")
    }
}
