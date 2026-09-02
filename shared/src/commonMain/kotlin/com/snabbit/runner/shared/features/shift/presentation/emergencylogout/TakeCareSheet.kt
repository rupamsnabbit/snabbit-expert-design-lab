package com.snabbit.runner.shared.features.shift.presentation.emergencylogout
import com.snabbit.design.atoms.SnabbitImage
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.snabbit.design.atoms.SnabbitButton
import com.snabbit.design.atoms.SnabbitButtonSize
import com.snabbit.design.atoms.SnabbitButtonStyle
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.atoms.SnabbitTextVariant
import com.snabbit.runner.shared.resources.Res
import com.snabbit.runner.shared.resources.take_care_heart
import org.jetbrains.compose.resources.painterResource
import com.snabbit.design.theme.SnabbitColorsLight
import com.snabbit.design.theme.SnabbitTheme

/**
 * "Take care!" sheet — Figma 7455:41537 / Dart `take_care_sheet.dart`. Shown
 * after a successful period-leave emergency logout.
 *
 * Layout (top → bottom): 100dp heart illustration, "Take care!" title,
 * "No red card applied" subtitle, full-width "Okay" CTA. Heart asset is
 * bundled (`take_care_heart.png` from Dart's `assets-expert.snabbit.com`).
 */
@Composable
fun TakeCareSheet(
    strings: com.snabbit.runner.shared.features.shift.presentation.emergencylogout.EmergencyLogoutStrings,
    onDone: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = SnabbitTheme.spacing.componentPaddingMd, vertical = SnabbitTheme.spacing.componentPaddingSm),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.componentGapLg),
    ) {
        SnabbitImage(
            painter = painterResource(Res.drawable.take_care_heart),
            contentDescription = null,
            modifier = Modifier.size(100.dp),
        )
        Column(
            modifier = Modifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.componentGapXs),
        ) {
            // "Take care!" — gray-800, 24sp semibold
            SnabbitText(
                text = strings.takeCareTitle,
                variant = SnabbitTextVariant.Heading2,
                fontWeight = FontWeight.SemiBold,
                color = SnabbitColorsLight.gray800,
                textAlign = TextAlign.Center,
            )
            // "No red card applied" — gray-500, 12sp medium
            SnabbitText(
                text = strings.takeCareBody,
                variant = SnabbitTextVariant.Caption,
                color = SnabbitTheme.colors.textSecondary,
                textAlign = TextAlign.Center,
            )
        }
        SnabbitButton(
            text = strings.takeCareCta,
            onClick = onDone,
            style = SnabbitButtonStyle.Primary,
            size = SnabbitButtonSize.L,
            fullWidth = true,
            modifier = Modifier.fillMaxWidth(),
        )
    }
}
