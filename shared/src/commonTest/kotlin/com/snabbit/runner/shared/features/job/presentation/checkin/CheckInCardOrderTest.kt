package com.snabbit.runner.shared.features.job.presentation.checkin

import kotlin.test.Test
import kotlin.test.assertEquals

/**
 * B10: the check-in body swaps the PRICING and ADDRESS cards per state. [checkInCardOrder]
 * is the pure ordering decision behind that swap (the composable keys the two items so the
 * flip animates); these tests pin the order for both states.
 */
class CheckInCardOrderTest {

    @Test
    fun accepted_no_penalty_keeps_pricing_above_address() {
        assertEquals(
            listOf(CheckInCard.Pricing, CheckInCard.Address),
            checkInCardOrder(penaltyActive = false),
        )
    }

    @Test
    fun delayed_checkin_penalty_puts_address_above_pricing() {
        assertEquals(
            listOf(CheckInCard.Address, CheckInCard.Pricing),
            checkInCardOrder(penaltyActive = true),
        )
    }

    @Test
    fun order_flips_when_penalty_toggles() {
        assertEquals(
            checkInCardOrder(penaltyActive = false).reversed(),
            checkInCardOrder(penaltyActive = true),
        )
    }
}
