package com.snabbit.runner.shared.features.tiering

import com.snabbit.runner.shared.features.tiering.domain.model.Tier
import com.snabbit.runner.shared.features.tiering.domain.model.TierCoinsData
import com.snabbit.runner.shared.features.tiering.domain.model.TierCoinsProgress
import com.snabbit.runner.shared.features.tiering.domain.model.TierTarget
import com.snabbit.runner.shared.features.tiering.domain.model.TierWeek
import com.snabbit.runner.shared.features.tiering.domain.model.TierWeekState
import kotlinx.collections.immutable.persistentListOf
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

/** Covers the active-week selection + milestone/fraction logic the coin card renders. */
class TierCoinsDataTest {

    private fun sample() = TierCoinsData(
        coinBalance = 1250,
        coins = TierCoinsProgress(
            currentWeek = 3,
            weeks = persistentListOf(
                TierWeek(week = 1, earned = 400, state = TierWeekState.COMPLETED),
                TierWeek(week = 2, earned = 350, state = TierWeekState.COMPLETED),
                TierWeek(
                    week = 3,
                    earned = 180,
                    state = TierWeekState.IN_PROGRESS,
                    targets = persistentListOf(
                        TierTarget(amount = 500, tier = Tier.GOLD),
                        TierTarget(amount = 800, tier = Tier.PINK_DIAMOND),
                    ),
                ),
            ),
        ),
    )

    @Test
    fun activeWeek_isTheWeekMatchingCurrentWeek() {
        val week = sample().coins?.activeWeek
        assertEquals(3, week?.week)
        assertEquals(180, week?.earned)
    }

    @Test
    fun maxTargetAmount_isTheLargestTarget() {
        assertEquals(800, sample().coins?.activeWeek?.maxTargetAmount)
    }

    @Test
    fun progressFraction_isEarnedOverMaxTarget() {
        assertEquals(0.225f, sample().coins?.activeWeek?.progressFraction ?: 0f, absoluteTolerance = 0.0001f)
    }

    @Test
    fun progressFraction_isZero_whenNoTargets() {
        val week = TierWeek(week = 1, earned = 100, targets = persistentListOf())
        assertEquals(0, week.maxTargetAmount)
        assertEquals(0f, week.progressFraction)
    }

    @Test
    fun activeWeek_isNull_whenCurrentWeekHasNoMatchingEntry() {
        val data = TierCoinsData(
            coins = TierCoinsProgress(
                currentWeek = 9,
                weeks = persistentListOf(TierWeek(week = 1, earned = 10)),
            ),
        )
        assertNull(data.coins?.activeWeek)
    }
}
