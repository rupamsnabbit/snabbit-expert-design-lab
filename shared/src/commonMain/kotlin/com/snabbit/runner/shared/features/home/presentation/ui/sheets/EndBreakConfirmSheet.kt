package com.snabbit.runner.shared.features.home.presentation.ui.sheets

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import com.snabbit.design.atoms.SnabbitButton
import com.snabbit.design.atoms.SnabbitButtonSize
import com.snabbit.design.atoms.SnabbitButtonStyle
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.atoms.SnabbitTextVariant
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.features.home.presentation.HomeStrings

/**
 * End-break confirmation — Figma "Shift & Job Lifecycle DS" (node 222:51525).
 * Rendered inside the shared [SnabbitBottomSheet] host (which owns the X +
 * scrim). Title question, magenta primary "End Break", and a light-pink
 * filled "Go Back" secondary.
 */
@Composable
fun EndBreakConfirmSheet(
    strings: HomeStrings,
    onEndBreak: () -> Unit,
    onGoBack: () -> Unit,
    endLoading: Boolean = false,
) {
    // DS SnabbitBottomSheet gives a bare ColumnScope (no content padding), so
    // pad the panel here. Matches the sibling sheets that pad via AttendanceSheetShell.
    // Figma (node 222:51528) pads the top further than the sides/bottom.
    Column(
        modifier = Modifier.fillMaxWidth().padding(
            PaddingValues(
                start = SnabbitTheme.spacing.componentPaddingMd,
                end = SnabbitTheme.spacing.componentPaddingMd,
                top = SnabbitTheme.spacing.componentPaddingXl,
                bottom = SnabbitTheme.spacing.componentPaddingMd,
            ),
        ),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        SnabbitText(
            text = strings.lunchEndConfirmTitle,
            variant = SnabbitTextVariant.Heading3,
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(SnabbitTheme.spacing.`10`))
        SnabbitButton(
            text = strings.lunchEndConfirmPrimaryCta,
            onClick = onEndBreak,
            style = SnabbitButtonStyle.Primary,
            size = SnabbitButtonSize.L,
            fullWidth = true,
            loading = endLoading,
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(SnabbitTheme.spacing.`4`))
        SnabbitButton(
            text = strings.lunchEndConfirmSecondaryCta,
            onClick = onGoBack,
            style = SnabbitButtonStyle.Secondary,
            size = SnabbitButtonSize.L,
            fullWidth = true,
            enabled = !endLoading,
        )
    }
}
