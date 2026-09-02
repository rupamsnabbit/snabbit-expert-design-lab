package com.snabbit.runner.shared.core.location

import kotlin.test.Test
import kotlin.test.assertEquals

class TrackingConfigTest {

    @Test
    fun defaults_matchTheCurrentGeolocatorSetup() {
        val config = TrackingConfig()

        assertEquals(LocationPriority.HIGH_ACCURACY, config.priority)
        assertEquals(5_000L, config.intervalMs)
        assertEquals(30_000L, config.timeoutMs)
    }

    @Test
    fun overrides_areApplied() {
        val config = TrackingConfig(
            priority = LocationPriority.BALANCED,
            intervalMs = 1_000L,
            timeoutMs = 10_000L,
        )

        assertEquals(LocationPriority.BALANCED, config.priority)
        assertEquals(1_000L, config.intervalMs)
        assertEquals(10_000L, config.timeoutMs)
    }
}
