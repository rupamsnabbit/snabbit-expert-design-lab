package com.snabbit.runner.shared.features.awol.presentation.ui

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.atoms.SnabbitTextVariant
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.features.awol.domain.AwolPhase
import com.snabbit.runner.shared.ui.components.StadiumProgressPill

/**
 * AwolCountdownMeter — the §2A stadium/pill countdown ("TIME LEFT 15:23"): a subtle full
 * track with the remaining fraction drawn over it in the phase accent (red for breach and
 * movement-required — payload/phase-driven, FR-14; green for re-entered). Behaviour is
 * unchanged from the contract: `deadline − now`, recomputed at 1 Hz by the coordinator;
 * this composable only renders [remainingSeconds] of [totalSeconds].
 *
 * The stadium ring is drawn by the shared [StadiumProgressPill] (`ui/components`), which sweeps
 * top-center / clockwise — AWOL follows the **job in-progress timer's** appearance (that pill is
 * the reference). Colours are the phase accent tokens (breach → textError, re-entered →
 * textSuccess); size stays 196×96 / 5dp. The design-system `SnabbitPillProgress` (different
 * sweep + palette) is deliberately left untouched (check-in timers).
 */
@Composable
fun AwolCountdownMeter(
    remainingSeconds: Int,
    totalSeconds: Int,
    phase: AwolPhase,
    timeLeftLabel: String,
    modifier: Modifier = Modifier,
) {
    val accent = awolAccent(phase)
    val fraction = if (totalSeconds > 0) {
        remainingSeconds.toFloat() / totalSeconds.toFloat()
    } else {
        0f
    }
    StadiumProgressPill(
        progress = fraction,
        trackColor = SnabbitTheme.colors.borderSubtle,
        progressColor = accent,
        modifier = modifier.width(196.dp).height(96.dp),
        strokeWidth = 5.dp,
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier.padding(horizontal = 24.dp),
        ) {
            SnabbitText(
                text = timeLeftLabel,
                variant = SnabbitTextVariant.Caption,
                color = SnabbitTheme.colors.textSecondary,
            )
            SnabbitText(
                text = formatAwolMmSs(remainingSeconds),
                variant = SnabbitTextVariant.Display,
                color = accent,
            )
        }
    }
}
