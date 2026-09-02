package com.snabbit.runner.shared.features.home.presentation.ui.sheets

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
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
import com.snabbit.design.organisms.SnabbitBottomSheet
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.features.home.presentation.HomeStrings
import com.snabbit.runner.shared.resources.Res
import com.snabbit.runner.shared.resources.hotspot_pin
import org.jetbrains.compose.resources.painterResource

/**
 * Non-dismissible GPS-off gate (ECPO-873, reduced scope). Dart's app-startup flow
 * already owns location permission/background/precise before Home mounts, so this
 * sheet only ever fires for one condition: the device's GPS service is off. Single
 * static state — icon + title + body + the "Turn on GPS" CTA, which fires
 * [com.snabbit.runner.shared.features.home.presentation.HomeUiIntent.EnableLocation].
 * `showClose = false` + `onDismissRequest = {}` make it a hard gate (Dart `PopScope`
 * + `isDismissible: false`).
 */
@Composable
fun EnableLocationSheet(
    visible: Boolean,
    strings: HomeStrings,
    onEnable: () -> Unit,
) {
    SnabbitBottomSheet(
        visible = visible,
        onDismissRequest = {},
        showClose = false,
        // DS uses contentDescription as the pane's paneTitle (not a close-button label),
        // and this gate is non-dismissible — announce the descriptive title, not "Close".
        contentDescription = strings.locationEnableTitle,
    ) {
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
            Image(
                painter = painterResource(Res.drawable.hotspot_pin),
                contentDescription = null,
                modifier = Modifier.size(72.dp),
            )
            Spacer(Modifier.height(SnabbitTheme.spacing.`6`))
            SnabbitText(
                text = strings.locationEnableTitle,
                variant = SnabbitTextVariant.Heading3,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth(),
            )
            Spacer(Modifier.height(SnabbitTheme.spacing.`4`))
            SnabbitText(
                text = strings.locationEnableBody,
                variant = SnabbitTextVariant.BodyMd,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth(),
            )
            Spacer(Modifier.height(SnabbitTheme.spacing.`10`))
            SnabbitButton(
                text = strings.locationEnableCta,
                onClick = onEnable,
                style = SnabbitButtonStyle.Primary,
                size = SnabbitButtonSize.L,
                fullWidth = true,
                modifier = Modifier.fillMaxWidth(),
            )
        }
    }
}
