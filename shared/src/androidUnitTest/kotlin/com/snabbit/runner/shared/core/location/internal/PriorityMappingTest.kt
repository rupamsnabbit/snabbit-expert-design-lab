package com.snabbit.runner.shared.core.location.internal

import com.google.android.gms.location.Priority
import com.snabbit.runner.shared.core.location.LocationPriority
import org.junit.Assert.assertEquals
import org.junit.Test

/** Verifies the LocationPriority → Google Play services Priority mapping is correct and exhaustive. */
class PriorityMappingTest {

    @Test
    fun mapsEveryPriorityToItsGmsConstant() {
        assertEquals(Priority.PRIORITY_HIGH_ACCURACY, LocationPriority.HIGH_ACCURACY.toGmsPriority())
        assertEquals(Priority.PRIORITY_BALANCED_POWER_ACCURACY, LocationPriority.BALANCED.toGmsPriority())
        assertEquals(Priority.PRIORITY_LOW_POWER, LocationPriority.LOW_POWER.toGmsPriority())
        assertEquals(Priority.PRIORITY_PASSIVE, LocationPriority.PASSIVE.toGmsPriority())
    }
}
