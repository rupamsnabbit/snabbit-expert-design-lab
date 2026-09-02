package com.snabbit.runner.shared.features.tiering.presentation

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Outline
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.runner.shared.core.designsystem.TierColors
import com.snabbit.runner.shared.features.tiering.domain.model.Tier
import com.snabbit.runner.shared.features.tiering.domain.model.TierCoinsData
import com.snabbit.runner.shared.features.tiering.domain.model.TierWeek

/**
 * A centred row of up to [maxFlags] (≤4) "Week N" flags — one per week in the
 * `tier_nudge` coins body ([data]). Each flag is the pennant ([WeekFlagShape],
 * ported from the Flutter `week_coin_flag.svg`) filled with the runner's [tier]
 * colour, with "Week N" centred in white. The current week (`current_week`) is
 * full opacity; preceding weeks are dimmed to 30%. When `current_week` is unknown
 * the whole row stays full opacity (mirrors the Flutter fix — no all-dimmed row).
 *
 * When there are more than [maxFlags] weeks the row is windowed so the current
 * week stays visible (matching the Flutter `_windowed`).
 */
@Composable
fun TierNudgeWeekFlags(
    data: TierCoinsData,
    tier: Tier,
    modifier: Modifier = Modifier,
    maxFlags: Int = MAX_FLAGS,
    strings: TieringStrings = rememberTieringStrings(),
) {
    val coins = data.coins
    val weeks = coins?.weeks.orEmpty()
    if (weeks.isEmpty()) return
    val currentWeek = coins?.currentWeek
    val visible = windowed(weeks, currentWeek, maxFlags.coerceIn(0, MAX_FLAGS))

    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(4.dp, Alignment.CenterHorizontally),
        verticalAlignment = Alignment.Top,
    ) {
        visible.forEach { week ->
            WeekFlag(
                weekNumber = week.week,
                tier = tier,
                // Highlight the current week; when current_week is unknown keep the
                // whole row at full opacity instead of dimming every flag to 30%.
                current = currentWeek == null || week.week == currentWeek,
                weekWord = strings.weekWord,
            )
        }
    }
}

/**
 * At most [maxFlags] flags. With more weeks than that, window so the current week
 * stays visible (the [maxFlags] weeks ending at it); if the current week isn't
 * found, fall back to the first [maxFlags] in order.
 */
private fun windowed(weeks: List<TierWeek>, currentWeek: Int?, maxFlags: Int): List<TierWeek> {
    if (weeks.size <= maxFlags) return weeks
    val idx = if (currentWeek == null) -1 else weeks.indexOfFirst { it.week == currentWeek }
    if (idx < 0) return weeks.take(maxFlags)
    val end = if (idx + 1 < maxFlags) maxFlags else idx + 1
    return weeks.subList(end - maxFlags, end)
}

@Composable
private fun WeekFlag(weekNumber: Int?, tier: Tier, current: Boolean, weekWord: String) {
    Box(
        modifier = Modifier
            .width(68.dp)
            .height(20.dp)
            .alpha(if (current) 1f else 0.3f)
            .background(TierColors.weekFlag(tier), WeekFlagShape),
        contentAlignment = Alignment.Center,
    ) {
        SnabbitText(
            text = "$weekWord ${weekNumber ?: ""}".trim(),
            fontSize = 10.sp,
            fontWeight = FontWeight.Medium,
            color = TierColors.onAccent,
        )
    }
}

private const val MAX_FLAGS = 4

/** The pennant outline (rounded top, scalloped bottom), scaled from the 68×19 Flutter SVG. */
private val WeekFlagShape = object : Shape {
    override fun createOutline(
        size: Size,
        layoutDirection: LayoutDirection,
        density: Density,
    ): Outline {
        val sx = size.width / 68f
        val sy = size.height / 19f
        fun px(v: Float) = v * sx
        fun py(v: Float) = v * sy
        val path = Path().apply {
            moveTo(px(0f), py(0f))
            lineTo(px(68f), py(0f))
            cubicTo(px(65.7909f), py(0f), px(64f), py(1.79086f), px(64f), py(4f))
            lineTo(px(64f), py(16.7308f))
            cubicTo(px(64f), py(18.2116f), px(62.422f), py(19.1584f), px(61.1154f), py(18.4615f))
            lineTo(px(60.25f), py(18f))
            cubicTo(px(57.9062f), py(16.75f), px(55.0938f), py(16.75f), px(52.75f), py(18f))
            cubicTo(px(50.4062f), py(19.25f), px(47.5938f), py(19.25f), px(45.25f), py(18f))
            cubicTo(px(42.9062f), py(16.75f), px(40.0938f), py(16.75f), px(37.75f), py(18f))
            cubicTo(px(35.4062f), py(19.25f), px(32.5938f), py(19.25f), px(30.25f), py(18f))
            cubicTo(px(27.9062f), py(16.75f), px(25.0938f), py(16.75f), px(22.75f), py(18f))
            cubicTo(px(20.4062f), py(19.25f), px(17.5938f), py(19.25f), px(15.25f), py(18f))
            cubicTo(px(12.9062f), py(16.75f), px(10.0938f), py(16.75f), px(7.75f), py(18f))
            lineTo(px(6.88462f), py(18.4615f))
            cubicTo(px(5.57802f), py(19.1584f), px(4f), py(18.2116f), px(4f), py(16.7308f))
            lineTo(px(4f), py(4f))
            cubicTo(px(4f), py(1.79086f), px(2.20914f), py(0f), px(0f), py(0f))
            close()
        }
        return Outline.Generic(path)
    }
}
