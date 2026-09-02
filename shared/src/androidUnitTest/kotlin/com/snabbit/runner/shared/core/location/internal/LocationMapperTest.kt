package com.snabbit.runner.shared.core.location.internal

import android.location.Location
import android.os.Build
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Robolectric tests for [toModel]: the has*()-guarded field mapping and the SDK-dependent
 * mock-detection branch (isMock on API 31+, isFromMockProvider below).
 */
@RunWith(RobolectricTestRunner::class)
class LocationMapperTest {

    @Test
    @Config(sdk = [Build.VERSION_CODES.TIRAMISU])
    fun mapsAllPresentFields() {
        val location = Location("gps").apply {
            latitude = 12.9716
            longitude = 77.5946
            accuracy = 5.0f
            altitude = 920.0
            verticalAccuracyMeters = 3.0f
            bearing = 90.0f
            bearingAccuracyDegrees = 2.0f
            speed = 4.5f
            speedAccuracyMetersPerSecond = 1.0f
            time = 1_700_000_000_000L
        }

        val model = location.toModel()

        assertEquals(12.9716, model.latitude, 1e-9)
        assertEquals(77.5946, model.longitude, 1e-9)
        assertEquals(5.0f, model.accuracy)
        assertEquals(920.0, model.altitude!!, 1e-9)
        assertEquals(3.0f, model.altitudeAccuracy)
        assertEquals(90.0f, model.heading)
        assertEquals(2.0f, model.headingAccuracy)
        assertEquals(4.5f, model.speed)
        assertEquals(1.0f, model.speedAccuracy)
        assertEquals(1_700_000_000_000L, model.timestamp)
        assertTrue(model.collectedAt > 0)
    }

    @Test
    @Config(sdk = [Build.VERSION_CODES.TIRAMISU])
    fun absentOptionalFieldsMapToNull() {
        // A fresh Location reports has*() == false for everything except lat/long.
        val location = Location("network").apply {
            latitude = 1.0
            longitude = 2.0
        }

        val model = location.toModel()

        assertEquals(1.0, model.latitude, 1e-9)
        assertEquals(2.0, model.longitude, 1e-9)
        assertNull(model.accuracy)
        assertNull(model.altitude)
        assertNull(model.altitudeAccuracy)
        assertNull(model.heading)
        assertNull(model.headingAccuracy)
        assertNull(model.speed)
        assertNull(model.speedAccuracy)
    }

    @Test
    @Config(sdk = [Build.VERSION_CODES.S])
    fun detectsMock_onApi31Plus_viaIsMock() {
        val mock = Location("gps").apply {
            latitude = 1.0; longitude = 2.0; isMock = true
        }
        val real = Location("gps").apply {
            latitude = 1.0; longitude = 2.0
        }

        assertTrue(mock.toModel().isMocked)
        assertEquals(false, real.toModel().isMocked)
    }

    @Test
    @Config(sdk = [Build.VERSION_CODES.O])
    fun realLocation_onPreApi31_isNotMocked_viaIsFromMockProvider() {
        // The legacy isFromMockProvider path: a normal fix reports false (the true path requires a
        // hidden system API not exercisable here — covered on device).
        val real = Location("gps").apply {
            latitude = 1.0; longitude = 2.0
        }

        assertEquals(false, real.toModel().isMocked)
    }
}
