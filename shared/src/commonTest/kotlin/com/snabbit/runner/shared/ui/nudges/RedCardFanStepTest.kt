package com.snabbit.runner.shared.ui.nudges

import kotlin.test.Test
import kotlin.test.assertEquals

class RedCardFanStepTest {

    @Test
    fun one_and_two_cards_sit_side_by_side_at_the_full_34dp_offset() {
        assertEquals(34f, redCardFanStep(1))
        assertEquals(34f, redCardFanStep(2))
    }

    @Test
    fun from_three_the_step_compresses_to_keep_the_two_card_footprint() {
        // total spread = (shown - 1) * step stays == 34dp.
        assertEquals(17f, redCardFanStep(3))
        assertEquals(34f / 6f, redCardFanStep(7))
    }

    @Test
    fun non_positive_count_keeps_the_full_offset() {
        assertEquals(34f, redCardFanStep(0))
    }
}
