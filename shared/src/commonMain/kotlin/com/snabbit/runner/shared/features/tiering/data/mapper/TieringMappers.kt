package com.snabbit.runner.shared.features.tiering.data.mapper

import com.snabbit.runner.shared.features.tiering.data.remote.dto.TierCoinsDto
import com.snabbit.runner.shared.features.tiering.data.remote.dto.TierCoinsProgressDto
import com.snabbit.runner.shared.features.tiering.data.remote.dto.TierNudgeDto
import com.snabbit.runner.shared.features.tiering.data.remote.dto.TierTargetDto
import com.snabbit.runner.shared.features.tiering.data.remote.dto.TierWeekDto
import com.snabbit.runner.shared.features.tiering.domain.model.NudgeTheme
import com.snabbit.runner.shared.features.tiering.domain.model.Tier
import com.snabbit.runner.shared.features.tiering.domain.model.TierCoinsData
import com.snabbit.runner.shared.features.tiering.domain.model.TierCoinsProgress
import com.snabbit.runner.shared.features.tiering.domain.model.TierNudge
import com.snabbit.runner.shared.features.tiering.domain.model.TierTarget
import com.snabbit.runner.shared.features.tiering.domain.model.TierWeek
import com.snabbit.runner.shared.features.tiering.domain.model.TierWeekState
import kotlinx.collections.immutable.toImmutableList

internal fun TierNudgeDto.toDomain(): TierNudge = TierNudge(
    nudgeName = nudgeName,
    navigationRoute = navigationRoute,
    imageUrl = imageUrl,
    theme = NudgeTheme.fromWire(theme),
    // Recognised-theme only (NOT merely non-blank): a NEW/unknown wire theme → false, so its
    // dynamic image renders un-tinted instead of flattened by the fallback GENERIC tint.
    themeProvided = NudgeTheme.fromWireOrNull(theme) != null,
    nudgeDetails = nudgeDetails,
)

internal fun TierCoinsDto.toDomain(): TierCoinsData = TierCoinsData(
    coinBalance = coinBalance,
    coins = coins?.toDomain(),
)

private fun TierCoinsProgressDto.toDomain(): TierCoinsProgress = TierCoinsProgress(
    currentWeek = currentWeek,
    weeks = weeks.map { it.toDomain() }.toImmutableList(),
)

private fun TierWeekDto.toDomain(): TierWeek = TierWeek(
    week = week,
    earned = earned,
    state = TierWeekState.fromWire(state),
    targets = targets.map { it.toDomain() }.toImmutableList(),
)

private fun TierTargetDto.toDomain(): TierTarget = TierTarget(
    amount = amount,
    tier = Tier.fromWire(tier),
)
