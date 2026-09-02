package com.snabbit.runner.shared.features.home.presentation.ui.cards

import com.snabbit.design.atoms.SnabbitImage
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.snabbit.design.atoms.SnabbitButton
import com.snabbit.design.atoms.SnabbitButtonSize
import com.snabbit.design.atoms.SnabbitButtonStyle
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.runner.shared.features.home.domain.model.HomeCard
import com.snabbit.runner.shared.features.home.presentation.HomeStrings
import com.snabbit.runner.shared.features.home.presentation.HomeUiIntent
import com.snabbit.runner.shared.resources.Res
import com.snabbit.runner.shared.resources.tiffin
import com.snabbit.runner.shared.features.shift.lunch.domain.model.BreakColorState
import com.snabbit.runner.shared.ui.components.StadiumProgressPill
import org.jetbrains.compose.resources.painterResource
import com.snabbit.design.theme.SnabbitTheme

/**
 * Active-break card — the in-shift LUNCH lifecycle. Pink-gradient header with a
 * tiffin illustration, a `TIME LEFT` ring countdown, and the "End Break & Start
 * Earning" CTA. Design: Figma "Shift & Job Lifecycle DS" node 222-50277.
 *
 * Ring uses [StadiumProgressPill] (top-center, clockwise — Figma "Timers"
 * 371:6294) rather than the DS `SnabbitPillProgress` molecule, whose Compose
 * implementation sweeps left-start (see `InProgressTimerPill`'s usage note) —
 * the job in-progress timer and AWOL meter already standardized on this same
 * primitive for that reason.
 */
@Composable
fun LunchActiveCard(
    card: HomeCard.Lunch,
    strings: HomeStrings,
    onIntent: (HomeUiIntent) -> Unit,
    endLoading: Boolean = false,
) {
    val cardShape = RoundedCornerShape(SnabbitTheme.borderRadius.xl)
    // Ring DEPLETES as the break elapses — full ring at the start, shrinking
    // to a sliver near the end. Confirmed against Figma "Frame 2147243561":
    // 28:23 remaining renders a near-full green ring, 14:23 a half amber
    // ring, 05:23 a sliver red ring — i.e. progress == remaining / total.
    val fraction = if (card.totalSeconds > 0) {
        (card.remainingSeconds.toFloat() / card.totalSeconds).coerceIn(0f, 1f)
    } else 0f
    val tierColor = when (card.colorState) {
        BreakColorState.Initial, BreakColorState.Green -> SnabbitTheme.colors.textSuccess
        BreakColorState.Amber -> SnabbitTheme.colors.textWarning
        BreakColorState.Red -> SnabbitTheme.colors.textError
    }
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(cardShape)
            .background(SnabbitTheme.colors.bgPrimary, cardShape)
            // 2dp gray-200 border (Figma 222-50210).
            .border(width = SnabbitTheme.borderWidth.thicker, color = SnabbitTheme.colors.borderDefault, shape = cardShape)
            .padding(SnabbitTheme.spacing.componentPaddingMd),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        // Full-bleed lunch illustration header — pink bg is baked into the asset
        // (Figma 222-50280); no gradient token needed.
        SnabbitImage(
            painter = painterResource(Res.drawable.tiffin),
            contentDescription = null,
            modifier = Modifier
                .fillMaxWidth()
                .height(160.dp)
                .clip(RoundedCornerShape(SnabbitTheme.borderRadius.lg)),
            contentScale = ContentScale.Crop,
        )
        Spacer(Modifier.height(SnabbitTheme.spacing.`6`))
        // Countdown pill — Figma 222-50277 / "Timers" 371:6294.
        StadiumProgressPill(
            progress = fraction,
            trackColor = SnabbitTheme.colors.borderDefault,
            progressColor = tierColor,
            strokeWidth = 6.dp,
        ) {
            Column(
                modifier = Modifier.padding(horizontal = 38.dp, vertical = 18.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(2.dp, Alignment.CenterVertically),
            ) {
                val label = if (card.isStartingSoon) strings.lunchStartingInLabel else strings.lunchTimeLeftLabel
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
                    text = formatMmSs(card.remainingSeconds),
                    fontSize = 32.sp,
                    fontWeight = FontWeight.Bold,
                    color = tierColor,
                    textAlign = TextAlign.Center,
                )
            }
        }
        // No "End Break" while the break is still counting down to its start —
        // there's nothing to end yet, and tapping it read as a way to cancel the
        // upcoming break (UAT). The CTA appears once the break is actually running.
        if (!card.isStartingSoon) {
            Spacer(Modifier.height(SnabbitTheme.spacing.`6`))
            SnabbitButton(
                text = strings.lunchEndBreakCta,
                onClick = { onIntent(HomeUiIntent.RequestEndBreak) },
                style = SnabbitButtonStyle.Primary,
                size = SnabbitButtonSize.L,
                fullWidth = true,
                loading = endLoading,
            )
        }
    }
}

/** `mm:ss` for a countdown. Shared across the lunch card and the map pill (both
 *  in this `ui.cards` package). */
internal fun formatMmSs(totalSeconds: Int): String {
    val s = totalSeconds.coerceAtLeast(0)
    return "${(s / 60).toString().padStart(2, '0')}:${(s % 60).toString().padStart(2, '0')}"
}
