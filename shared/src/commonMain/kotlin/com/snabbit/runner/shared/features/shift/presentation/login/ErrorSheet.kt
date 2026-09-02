package com.snabbit.runner.shared.features.shift.presentation.login
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.snabbit.design.atoms.SnabbitButton
import com.snabbit.design.atoms.SnabbitButtonSize
import com.snabbit.design.atoms.SnabbitButtonStyle
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.atoms.SnabbitTextVariant
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.features.shift.presentation.login.ShiftLoginStrings

/**
 * Generic terminal-error sheet body — title + message + dismiss CTA.
 * Used for network/server/unknown failures where the only recovery is to
 * exit the flow.
 */
@Composable
fun ErrorSheet(
    message: String,
    strings: ShiftLoginStrings,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier,
) {
    // DS SnabbitBottomSheet gives a bare ColumnScope (no content padding) — pad here.
    Column(
        modifier = modifier.fillMaxWidth().padding(SnabbitTheme.spacing.componentPaddingMd),
        verticalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.componentGapLg),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        SnabbitText(
            text = strings.errorGenericTitle,
            variant = SnabbitTextVariant.Heading3,
            color = SnabbitTheme.colors.textPrimary,
            textAlign = TextAlign.Center,
        )
        SnabbitText(
            text = message,
            variant = SnabbitTextVariant.BodyMd,
            color = SnabbitTheme.colors.textSecondary,
            textAlign = TextAlign.Center,
        )
        SnabbitButton(
            text = strings.errorDismiss,
            onClick = onDismiss,
            style = SnabbitButtonStyle.Primary,
            size = SnabbitButtonSize.L,
            fullWidth = true,
            modifier = Modifier.fillMaxWidth(),
        )
    }
}
