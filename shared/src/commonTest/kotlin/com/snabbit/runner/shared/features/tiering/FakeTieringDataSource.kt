package com.snabbit.runner.shared.features.tiering

import com.snabbit.runner.shared.features.tiering.data.TieringDataSource
import com.snabbit.runner.shared.features.tiering.domain.model.TierCoinsData
import com.snabbit.runner.shared.features.tiering.domain.model.TierNudge
import com.snabbit.runner.shared.features.tiering.domain.model.TieringProfile
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow

/**
 * Deterministic [TieringDataSource] for tests: push [nudgeFlow] / [profileFlow]
 * to drive the ViewModel, and preset [coinsResult] for the `THE_COIN_NUDGE` path.
 */
class FakeTieringDataSource(
    val nudgeFlow: MutableStateFlow<TierNudge?> = MutableStateFlow(null),
    val profileFlow: MutableStateFlow<TieringProfile> = MutableStateFlow(TieringProfile()),
    val widgetNameFlow: MutableStateFlow<String?> = MutableStateFlow(null),
    var coinsResult: TierCoinsData? = null,
) : TieringDataSource {
    override val nudge: Flow<TierNudge?> = nudgeFlow
    override val profile: Flow<TieringProfile> = profileFlow
    override val widgetName: Flow<String?> = widgetNameFlow
    override fun coins(nudge: TierNudge): TierCoinsData? = coinsResult
}
