package com.snabbit.runner.shared.features.home.presentation.ui.sheets

import com.snabbit.design.atoms.SnabbitImage
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
import androidx.compose.ui.unit.dp
import com.snabbit.design.atoms.SnabbitButton
import com.snabbit.design.atoms.SnabbitButtonSize
import com.snabbit.design.atoms.SnabbitButtonStyle
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.atoms.SnabbitTextVariant
import com.snabbit.runner.shared.features.home.presentation.HomeStrings
import com.snabbit.runner.shared.resources.Res
import com.snabbit.runner.shared.resources.tiffin
import org.jetbrains.compose.resources.painterResource
import com.snabbit.design.theme.SnabbitTheme

/**
 * Break-offer sheet — auto-opened on the `LUNCH_REQUEST` envelope. Pink-gradient
 * tiffin header (mirrors [LunchActiveCard]), title, primary "Take break" CTA,
 * "I don't need a break" link below. Layout mirrors [EndBreakConfirmSheet] —
 * stacked full-width buttons — so the two break-flow sheets feel like one
 * pattern instead of one row / one column.
 */
@Composable
fun LunchRequestSheet(
    strings: HomeStrings,
    onTakeBreak: () -> Unit,
    onSkip: () -> Unit,
    takeLoading: Boolean = false,
    skipLoading: Boolean = false,
) {
    // DS SnabbitBottomSheet gives a bare ColumnScope (no content padding) — pad here.
    Column(
        modifier = Modifier.fillMaxWidth().padding(SnabbitTheme.spacing.componentPaddingMd),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        // Full-bleed lunch illustration header — mirrors LunchActiveCard; pink bg
        // is baked into the asset (Figma 222-50280), no gradient token needed.
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
        SnabbitText(
            text = strings.lunchRequestTitle,
            variant = SnabbitTextVariant.Heading3,
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(SnabbitTheme.spacing.`7`))
        SnabbitButton(
            text = strings.lunchTakeBreakCta,
            onClick = onTakeBreak,
            style = SnabbitButtonStyle.Primary,
            size = SnabbitButtonSize.L,
            fullWidth = true,
            enabled = !skipLoading,
            loading = takeLoading,
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(SnabbitTheme.spacing.`4`))
        SnabbitButton(
            text = strings.lunchSkipBreakCta,
            onClick = onSkip,
            style = SnabbitButtonStyle.LinkButton,
            size = SnabbitButtonSize.L,
            fullWidth = true,
            enabled = !takeLoading && !skipLoading,
            loading = skipLoading,
        )
    }
}
