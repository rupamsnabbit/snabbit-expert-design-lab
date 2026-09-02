package com.snabbit.runner.shared.features.shift.core.data.remote.dto

import kotlinx.serialization.json.Json
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

/**
 * `earning_loss` → [EmergencyLogoutAvailability.earningLossAmount] mapping
 * (ECPO-753): positive amounts surface as whole rupees; absent / zero /
 * negative collapse to null so the "Lose ₹X" tile hides (Dart parity).
 */
class EmergencyLogoutAvailabilityDtoTest {
    private val json = Json { ignoreUnknownKeys = true }

    private fun decode(body: String) =
        json.decodeFromString<EmergencyLogoutAvailabilityDto>(body).toDomain()

    @Test fun positiveEarningLoss_surfacesWholeRupees() {
        val d = decode("""{"max_emergency_logouts":1,"emergency_logouts_taken":0,"earning_loss":250.0}""")
        assertEquals(250, d.earningLossAmount)
    }

    @Test fun fractionalEarningLoss_truncatesLikeDart() {
        // Dart renders '₹${earningLoss.toInt()}' — mirror the truncation.
        assertEquals(199, decode("""{"earning_loss":199.75}""").earningLossAmount)
    }

    @Test fun absentEarningLoss_isNull() {
        assertNull(decode("""{"max_emergency_logouts":1,"emergency_logouts_taken":0}""").earningLossAmount)
    }

    @Test fun zeroEarningLoss_isNull() {
        assertNull(decode("""{"earning_loss":0.0}""").earningLossAmount)
    }

    @Test fun negativeEarningLoss_isNull() {
        assertNull(decode("""{"earning_loss":-10.0}""").earningLossAmount)
    }
}
