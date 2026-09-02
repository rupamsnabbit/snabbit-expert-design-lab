package com.snabbit.runner.shared.features.home.presentation.ui.cards

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.snabbit.design.atoms.SnabbitButton
import com.snabbit.design.atoms.SnabbitButtonSize
import com.snabbit.design.atoms.SnabbitButtonStyle
import com.snabbit.design.atoms.SnabbitIcon
import com.snabbit.design.atoms.SnabbitIconName
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.atoms.SnabbitTextVariant
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.features.home.presentation.HomeStrings
import com.snabbit.runner.shared.features.home.presentation.HomeUiIntent

/**
 * See-you-tomorrow takeover card (`RUNNER_SEE_YOU_TOMORROW`) — the CMP port of
 * Dart `see_you_tomorrow.dart`, shown after a shift logout. Occupies the whole
 * hero slot, mirroring the `SuspendedCard` layout (circular status icon →
 * centered title → primary CTA → outlined secondary), but positive: a success
 * check glyph instead of the amber warning.
 *
 * Two nav CTAs, both reusing existing Home effects (no data seam of its own):
 *  - "Go to Earnings" ([HomeUiIntent.TapGoToEarnings] → `NavigateToEarnings`).
 *  - "Refer and Earn" ([HomeUiIntent.TapReferAndEarn] → the shared refer decider,
 *    same destination as the Refer banner / Profile tile).
 */
@Composable
fun SeeYouTomorrowCard(
    strings: HomeStrings,
    onIntent: (HomeUiIntent) -> Unit,
) {
    val cardShape = RoundedCornerShape(SnabbitTheme.borderRadius.xl)
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(cardShape)
            .background(SnabbitTheme.colors.bgPrimary, cardShape)
            .border(width = 2.dp, color = SnabbitTheme.colors.borderDefault, shape = cardShape)
            .padding(SnabbitTheme.spacing.componentPaddingLg),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.`6`),
    ) {
        // Circular status badge — success check on a soft green disc (parity
        // with Dart's positive "See you tomorrow" illustration slot).
        Box(
            modifier = Modifier
                .size(96.dp)
                .clip(CircleShape)
                .background(SnabbitTheme.colors.bgSuccessSubtle),
            contentAlignment = Alignment.Center,
        ) {
            SnabbitIcon(
                name = SnabbitIconName.CheckCircle,
                size = 48.dp,
                color = SnabbitTheme.colors.iconSuccess,
            )
        }

        SnabbitText(
            text = strings.seeYouTomorrowTitle,
            variant = SnabbitTextVariant.Heading2,
            fontWeight = FontWeight.SemiBold,
            color = SnabbitTheme.colors.textPrimary,
            textAlign = TextAlign.Center,
        )

        // Primary CTA — "Go to Earnings" (reuses the suspended card's copy + intent).
        SnabbitButton(
            text = strings.suspendedGoToEarningsCta,
            onClick = { onIntent(HomeUiIntent.TapGoToEarnings) },
            style = SnabbitButtonStyle.Primary,
            size = SnabbitButtonSize.L,
            fullWidth = true,
            leadingIcon = {
                SnabbitIcon(
                    name = SnabbitIconName.Star,
                    size = 20.dp,
                    color = SnabbitTheme.colors.textInverse,
                )
            },
        )

        // Secondary CTA — "Refer and Earn" (outlined ghost, Share glyph).
        SnabbitButton(
            text = strings.seeYouTomorrowReferCta,
            onClick = { onIntent(HomeUiIntent.TapReferAndEarn) },
            style = SnabbitButtonStyle.NeutralStroke,
            size = SnabbitButtonSize.L,
            fullWidth = true,
            leadingIcon = {
                SnabbitIcon(
                    name = SnabbitIconName.Share,
                    size = 20.dp,
                    color = SnabbitTheme.colors.textPrimary,
                )
            },
        )
    }
}
