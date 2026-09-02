package com.snabbit.runner.shared.features.kavach.sos.ui.components

import com.snabbit.runner.shared.resources.Res
import com.snabbit.runner.shared.resources.kavach_sos_alert_confirm
import com.snabbit.runner.shared.resources.kavach_sos_alert_deny
import com.snabbit.runner.shared.resources.kavach_sos_alert_title
import com.snabbit.runner.shared.resources.sos_confirm_kavach_pill
import com.snabbit.runner.shared.resources.sos_confirmation_wave_illu
import com.snabbit.runner.shared.resources.sos_confirmation_siron_bg
import com.snabbit.runner.shared.resources.sos_confirmation_siron_icon
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.snabbit.design.atoms.SnabbitButton
import com.snabbit.design.atoms.SnabbitButtonSize
import com.snabbit.design.atoms.SnabbitButtonStyle
import com.snabbit.design.atoms.SnabbitImage
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.atoms.SnabbitTextVariant
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.features.kavach.shared.designgaps.KavachDesignGaps
import org.jetbrains.compose.resources.painterResource
import org.jetbrains.compose.resources.stringResource
import org.jetbrains.compose.ui.tooling.preview.Preview

/**
 * SOS-trigger alert ("Are you in danger?") — Figma 421-18176. Salmon→white gradient backdrop, top-
 * aligned "Snabbit Kavach" pill, the baked composed hero (`sos_confirm_bg` = circles + wave + dots +
 * siren, node 2417-19958) — one image, no separate siren overlay — then Display/32-Bold #303030 title
 * and native Destructive / Tertiary CTAs with emoji inline. Hosted in `SnabbitBottomSheet` (its close-X
 * + scrim + back all map to [onDeny]).
 */
@Composable
fun SosAlertSheetContent(
    onConfirm: () -> Unit,
    onDeny: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                Brush.verticalGradient(
                    0.0f to SnabbitTheme.colors.bgErrorStrong,
                    0.15f to SnabbitTheme.colors.bgErrorStrong,
                    0.6f to SnabbitTheme.colors.bgPrimary,
                ),
            )
            .padding(bottom = SnabbitTheme.spacing.`7`),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        // "Snabbit Kavach" pill — top-aligned at the sheet edge (Figma 2417-19743).
        SnabbitImage(
            painter = painterResource(Res.drawable.sos_confirm_kavach_pill),
            contentDescription = "Snabbit Kavach",
            contentScale = ContentScale.Fit,
            modifier = Modifier.height(KavachDesignGaps.SosConfirmSheet.pillHeight),
        )
        // Composed hero (circles + wave + 4 dots + siren) baked as one image — Figma 2417-19958.
        Box(
            modifier = Modifier.fillMaxWidth().padding(top = 20.dp),
            contentAlignment = Alignment.TopCenter,
        ) {
            SnabbitImage(
                painter = painterResource(Res.drawable.sos_confirmation_wave_illu),
                contentDescription = "Snabbit Kavach SOS",
                contentScale = ContentScale.FillWidth,
                modifier = Modifier.fillMaxWidth().padding(top = 24.dp).height(100.dp),
            )
            SnabbitImage(
                painter = painterResource(Res.drawable.sos_confirmation_siron_bg),
                contentDescription = "Snabbit Kavach SOS",
                modifier = Modifier.size(240.dp),
            )
            SnabbitImage(
                painter = painterResource(Res.drawable.sos_confirmation_siron_icon),
                contentDescription = "Snabbit Kavach SOS",
                modifier = Modifier.width(168.dp).height(150.dp).padding(top = 36.dp),
            )
        }
        Column(
            modifier = Modifier.fillMaxWidth().padding(horizontal = SnabbitTheme.spacing.`5`),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            SnabbitText(
                text = stringResource(Res.string.kavach_sos_alert_title),
                variant = SnabbitTextVariant.Display,        // Figma Display/32
                fontWeight = FontWeight.Bold,                // Figma 700 (DS Display is 600)
                color = SnabbitTheme.colors.textNeutralInk,  // #303030
                textAlign = TextAlign.Center,
            )
            Spacer(Modifier.height(KavachDesignGaps.SosConfirmSheet.titleToButtonsGap)) // Figma 41
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.`4`), // 12
            ) {
                SnabbitButton(
                    text = "😰   " + stringResource(Res.string.kavach_sos_alert_confirm),
                    onClick = onConfirm,
                    style = SnabbitButtonStyle.Destructive,  // native #DC2626 + white
                    size = SnabbitButtonSize.L,
                    fullWidth = true,
                )
                SnabbitButton(
                    text = "😊   " + stringResource(Res.string.kavach_sos_alert_deny),
                    onClick = onDeny,
                    style = SnabbitButtonStyle.Tertiary,     // native transparent + #F70F79 text + border
                    size = SnabbitButtonSize.L,
                    fullWidth = true,
                )
            }
        }
    }
}

@Preview
@Composable
private fun SosAlertSheetContentPreview() {
    SnabbitTheme {
        SosAlertSheetContent(onConfirm = { }, onDeny = {})
    }
}
