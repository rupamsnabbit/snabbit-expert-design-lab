package com.snabbit.runner.shared.features.job.presentation.inprogress

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.ui.components.StadiumProgressPill

/**
 * In-progress countdown pill — the reference appearance for the shared stadium timer. The ring
 * is drawn by [StadiumProgressPill] (`ui/components`), sweeping top-center / clockwise (Figma
 * "Timers" 371:6294); the AWOL countdown meter shares the same generic so it follows this pill.
 * The DS `SnabbitPillProgress` (different sweep + palette) stays untouched (check-in timers).
 *
 * Colours use the closest existing SnabbitTheme semantic tokens rather than the raw Figma tier
 * hexes: green → `text.success`, yellow → `text.warning`, red → `text.error` (the same red the
 * SnabbitActionFooter urgent timer uses). Track = `border.default`. No raw colours.
 */
@Composable
internal fun InProgressTimerPill(
    time: String,
    color: InProgressColor,
    label: String,
    progress: Float,
    modifier: Modifier = Modifier,
) {
    val tierColor = when (color) {
        InProgressColor.Green -> SnabbitTheme.colors.textSuccess
        InProgressColor.Yellow -> SnabbitTheme.colors.textWarning
        InProgressColor.Red -> SnabbitTheme.colors.textError
    }

    StadiumProgressPill(
        progress = progress,
        trackColor = SnabbitTheme.colors.borderDefault,
        progressColor = tierColor,
        modifier = modifier,
        strokeWidth = 6.dp,
    ) {
        Column(
            modifier = Modifier.padding(horizontal = 38.dp, vertical = 18.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(2.dp, Alignment.CenterVertically),
        ) {
            if (label.isNotEmpty()) {
                SnabbitText(
                    text = label,
                    fontSize = 10.sp,
                    fontWeight = FontWeight.Medium,
                    color = SnabbitTheme.colors.textSecondary,
                    textAlign = TextAlign.Center,
                )
            }
            SnabbitText(
                text = time,
                fontSize = 32.sp,
                fontWeight = FontWeight.Bold,
                color = tierColor,
                textAlign = TextAlign.Center,
            )
        }
    }
}
