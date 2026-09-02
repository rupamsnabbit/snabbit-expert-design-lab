package com.snabbit.runner.shared.features.kavach.sos.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.SnackbarHostState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import com.snabbit.design.atoms.SnabbitButton
import com.snabbit.design.atoms.SnabbitButtonSize
import com.snabbit.design.atoms.SnabbitButtonStyle
import com.snabbit.design.atoms.SnabbitImage
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.atoms.SnabbitTextVariant
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.features.kavach.shared.designgaps.KavachDesignGaps
import com.snabbit.runner.shared.features.kavach.sos.ui.contracts.SosActiveIntent
import com.snabbit.runner.shared.features.kavach.sos.ui.contracts.SosActiveUiState
import com.snabbit.runner.shared.resources.Res
import com.snabbit.runner.shared.resources.active_sos_background
import com.snabbit.runner.shared.resources.sos_action_error
import com.snabbit.runner.shared.resources.sos_active_bg_shadow
import com.snabbit.runner.shared.resources.sos_active_siron_icon
import com.snabbit.runner.shared.resources.sos_active_snabbit_kavach_pill
import com.snabbit.runner.shared.resources.sos_call_team
import com.snabbit.runner.shared.resources.sos_help_subtitle
import com.snabbit.runner.shared.resources.sos_help_title
import com.snabbit.runner.shared.resources.sos_mark_safe
import com.snabbit.runner.shared.resources.active_sos_bg
import com.snabbit.runner.shared.core.designsystem.SnabbitScreen
import org.jetbrains.compose.resources.painterResource
import org.jetbrains.compose.resources.stringResource
import org.jetbrains.compose.ui.tooling.preview.Preview

/**
 * "Help is on the way" — the full-screen state after the runner raises SOS.
 * Stateless: renders [uiState] and forwards actions via [onIntent].
 *
 * Pass-2 TODO (Figma 421-15691): add the top pink→white gradient banner (asset 2417-21155) behind the
 * content, swap the siren/glow/shadow rasters for the re-exported webps, and top-anchor the column to
 * the Figma offsets (currently screen-centered).
 */
@Composable
fun SosActiveScreen(
    uiState: SosActiveUiState,
    onIntent: (SosActiveIntent) -> Unit,
) {
    // Call-team / mark-safe failures were invisible before — surface as a transient snackbar (D2 clear).
    val snackbarHostState = remember { SnackbarHostState() }
    val actionError = stringResource(Res.string.sos_action_error)
    LaunchedEffect(uiState.error) {
        if (uiState.error != null) {
            snackbarHostState.showSnackbar(actionError)
            onIntent(SosActiveIntent.ErrorShown)
        }
    }

    SnabbitScreen(
        snackbarHostState = snackbarHostState,
        bottomBar = {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = SnabbitTheme.spacing.`6`, vertical = SnabbitTheme.spacing.`4`),
                verticalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.`4`),
            ) {
                SnabbitButton(
                    text = "📞   " + stringResource(Res.string.sos_call_team),
                    onClick = { onIntent(SosActiveIntent.CallSosTeam) },
                    style = SnabbitButtonStyle.Destructive,
                    size = SnabbitButtonSize.L,
                    fullWidth = true,
                )
                SnabbitButton(
                    text = "😊   " + stringResource(Res.string.sos_mark_safe),
                    onClick = { onIntent(SosActiveIntent.MarkSafe) },
                    style = SnabbitButtonStyle.Tertiary,
                    size = SnabbitButtonSize.L,
                    fullWidth = true,
                    enabled = !uiState.ending,
                )
            }
        },
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    // Figma 421-15691: pink → white top-anchored wash (the exported banner was empty).
                    Brush.verticalGradient(
                        0.0f to SnabbitTheme.colors.bgErrorStrong,
                        0.45f to SnabbitTheme.colors.bgPrimary,
                    ),
                )
                .padding(padding),
        ) {
            SnabbitImage(
                painter = painterResource(Res.drawable.active_sos_bg),
                contentDescription = "Snabbit Kavach",
                contentScale = ContentScale.Fit,
            )
            // Top-anchored content (Figma offsets), horizontally inset.
            Column(
                modifier = Modifier
                    .align(Alignment.TopCenter)
                    .fillMaxWidth()
                    .padding(horizontal = SnabbitTheme.spacing.`7`),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Spacer(Modifier.height(SnabbitTheme.spacing.`5`))
                // "Snabbit Kavach" pill.
                SnabbitImage(
                    painter = painterResource(Res.drawable.sos_active_snabbit_kavach_pill),
                    contentDescription = "Snabbit Kavach",
                    contentScale = ContentScale.Fit,
                    modifier = Modifier.height(KavachDesignGaps.SosActive.pillHeight),
                )
                Spacer(Modifier.height(SnabbitTheme.spacing.`8`))
                // Siren beacon over a faint radial glow.
                Box(contentAlignment = Alignment.Center) {
                    SnabbitImage(
                        painter = painterResource(Res.drawable.active_sos_background),
                        contentDescription = null,
                        contentScale = ContentScale.Fit,
                        modifier = Modifier.fillMaxWidth(KavachDesignGaps.SosActive.glowWidthFraction),
                    )
                    SnabbitImage(
                        painter = painterResource(Res.drawable.sos_active_siron_icon),
                        contentDescription = null,
                        contentScale = ContentScale.Fit,
                        modifier = Modifier.fillMaxWidth(KavachDesignGaps.SosActive.sirenWidthFraction),
                    )
                }
                // Soft shadow beneath the siren.
                SnabbitImage(
                    painter = painterResource(Res.drawable.sos_active_bg_shadow),
                    contentDescription = null,
                    contentScale = ContentScale.FillWidth,
                    modifier = Modifier.fillMaxWidth(KavachDesignGaps.SosActive.shadowWidthFraction),
                )
                Spacer(Modifier.height(SnabbitTheme.spacing.`11`))
                // Figma: both lines are Display/32-Bold #303030.
                SnabbitText(
                    text = stringResource(Res.string.sos_help_title),
                    variant = SnabbitTextVariant.Display,
                    fontWeight = FontWeight.Bold,
                    color = SnabbitTheme.colors.textNeutralInk,
                    textAlign = TextAlign.Center,
                )
                SnabbitText(
                    text = stringResource(Res.string.sos_help_subtitle),
                    variant = SnabbitTextVariant.Display,
                    fontWeight = FontWeight.Bold,
                    color = SnabbitTheme.colors.textNeutralInk,
                    textAlign = TextAlign.Center,
                )
            }
        }
    }
}

@Preview
@Composable
fun SosActiveScreenPreview() {
    SnabbitTheme {
        SosActiveScreen(
            uiState = SosActiveUiState(),
            onIntent = {}
        )
    }
}
