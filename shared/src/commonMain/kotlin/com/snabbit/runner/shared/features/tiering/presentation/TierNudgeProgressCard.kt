package com.snabbit.runner.shared.features.tiering.presentation

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.snabbit.design.atoms.SnabbitRemoteImage
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.core.designsystem.TierColors
import com.snabbit.runner.shared.features.tiering.domain.model.Tier
import com.snabbit.runner.shared.features.tiering.domain.model.TierCoinsData
import com.snabbit.runner.shared.features.tiering.domain.model.TierTarget
import kotlinx.collections.immutable.ImmutableList
import kotlinx.collections.immutable.persistentListOf

/**
 * The Snabbit-coins tier nudge (`THE_COIN_NUDGE`): a header naming the [tier]
 * and a body plotting the active week's coin earnings against its milestone
 * targets. Mirrors the Flutter `TierNudgeProgressCard`.
 *
 * Data-driven off [TierCoinsData.coins]'s active week (earned = current value,
 * targets = milestones, max target = bar scale). Per-tier colours come from
 * [TierColors] — accent (header bg + progress fill + border) and tint (body) —
 * mirroring the Flutter `AppColors.nudgeTier*` palette. The week-flag pennants
 * render directly below the card (Flutter parity).
 */
@Composable
fun TierNudgeProgressCard(
    tier: Tier,
    data: TierCoinsData,
    modifier: Modifier = Modifier,
    onClick: (() -> Unit)? = null,
    strings: TieringStrings = rememberTieringStrings(),
) {
    val shape = RoundedCornerShape(SnabbitTheme.borderRadius.lg)
    val activeWeek = data.coins?.activeWeek
    val earned = activeWeek?.earned ?: 0
    val maxTarget = activeWeek?.maxTargetAmount ?: 0
    val fraction = activeWeek?.progressFraction ?: 0f
    val milestones = activeWeek?.targets ?: persistentListOf()

    Column(modifier = modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(shape)
                .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier)
                .border(SnabbitTheme.borderWidth.thicker, TierColors.accent(tier), shape),
        ) {
        // ── Header (per-tier accent) ──
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(TierColors.accent(tier))
                .padding(horizontal = 12.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            SnabbitRemoteImage(
                model = TierAssets.badgeUrl(tier),
                contentDescription = null,
                modifier = Modifier.size(20.dp),
                contentScale = ContentScale.Fit,
            )
            Spacer(Modifier.width(4.dp))
            SnabbitText(
                text = "${tier.displayName} ${strings.levelWord}",
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
                color = TierColors.onAccent,
            )
        }
        // ── Body (per-tier tint) ──
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(TierColors.tint(tier))
                .padding(horizontal = 12.dp, vertical = 16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .clip(CircleShape)
                    .background(SnabbitTheme.colors.bgBrandSubtle),
                contentAlignment = Alignment.Center,
            ) {
                SnabbitRemoteImage(
                    model = TierAssets.COIN_URL,
                    contentDescription = null,
                    modifier = Modifier.size(24.dp),
                    contentScale = ContentScale.Fit,
                )
            }
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    SnabbitText(
                        text = earned.toString(),
                        fontSize = 16.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = SnabbitTheme.colors.textPrimary,
                    )
                    Spacer(Modifier.width(4.dp))
                    SnabbitText(
                        text = strings.coinsLabel,
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Medium,
                        color = SnabbitTheme.colors.textSecondary,
                    )
                    Spacer(Modifier.weight(1f))
                    if (maxTarget > 0) {
                        SnabbitText(
                            text = maxTarget.toString(),
                            fontSize = 10.sp,
                            fontWeight = FontWeight.Normal,
                            color = SnabbitTheme.colors.textSecondary,
                        )
                    }
                }
                Spacer(Modifier.height(4.dp))
                MilestoneProgressBar(
                    fraction = fraction,
                    maxTarget = maxTarget,
                    milestones = milestones,
                    tier = tier,
                )
            }
        }
        }
        // Week-flag pennants below the card (Flutter parity — TierNudgeProgressCard
        // renders TierNudgeWeekFlags directly beneath the bordered card).
        TierNudgeWeekFlags(data = data, tier = tier, strings = strings)
    }
}

/**
 * The 8dp progress track + fill with each milestone tier badge plotted on top
 * at `amount / maxTarget`. Hand-built from layout primitives + DS tokens: no DS
 * progress atom hosts a milestone overlay (same rationale as `StadiumProgressPill`).
 */
@Composable
private fun MilestoneProgressBar(
    fraction: Float,
    maxTarget: Int,
    milestones: ImmutableList<TierTarget>,
    tier: Tier,
    modifier: Modifier = Modifier,
) {
    val milestoneSize = 16.dp
    val barShape = RoundedCornerShape(percent = 50)
    BoxWithConstraints(
        modifier = modifier
            .fillMaxWidth()
            .height(milestoneSize),
    ) {
        val widthPx = constraints.maxWidth.toFloat()
        val density = LocalDensity.current
        val milestonePx = with(density) { milestoneSize.toPx() }

        // Track (full width, vertically centred within the milestone-sized row).
        Box(
            modifier = Modifier
                .align(Alignment.CenterStart)
                .fillMaxWidth()
                .height(8.dp)
                .clip(barShape)
                .background(SnabbitTheme.colors.borderDefault),
        )
        // Fill (per-tier accent).
        Box(
            modifier = Modifier
                .align(Alignment.CenterStart)
                .fillMaxWidth(fraction)
                .height(8.dp)
                .clip(barShape)
                .background(TierColors.accent(tier)),
        )
        // Milestone badges plotted on top, centred on their target fraction.
        milestones.forEach { target ->
            val milestoneTier = target.tier ?: return@forEach
            val f = if (maxTarget <= 0) 0f else ((target.amount ?: 0).toFloat() / maxTarget).coerceIn(0f, 1f)
            val maxLeft = (widthPx - milestonePx).coerceAtLeast(0f)
            val leftPx = (f * widthPx - milestonePx / 2f).coerceIn(0f, maxLeft)
            val leftDp = with(density) { leftPx.toDp() }
            SnabbitRemoteImage(
                model = TierAssets.badgeUrl(milestoneTier),
                contentDescription = null,
                contentScale = ContentScale.Fit,
                modifier = Modifier
                    .align(Alignment.CenterStart)
                    .offset(x = leftDp)
                    .size(milestoneSize),
            )
        }
    }
}
