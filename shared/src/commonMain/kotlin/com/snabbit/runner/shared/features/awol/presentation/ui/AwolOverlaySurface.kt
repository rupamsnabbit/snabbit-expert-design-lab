package com.snabbit.runner.shared.features.awol.presentation.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.dp
import com.snabbit.design.atoms.SnabbitButton
import com.snabbit.design.atoms.SnabbitButtonSize
import com.snabbit.design.atoms.SnabbitButtonStyle
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.features.awol.domain.AwolStrings
import com.snabbit.runner.shared.features.awol.presentation.AwolSurface
import com.snabbit.runner.shared.features.awol.presentation.AwolUiIntent
import com.snabbit.runner.shared.features.awol.presentation.AwolViewModel

/**
 * AwolOverlaySurface — the over-other-apps surface (§9 routing: `OVERLAY`,
 * FR-10; §2A "Overlay" mockup): the modal card over the dimmed foreground
 * app, with the status badge ("MOVEMENT REQUIRED" / "HOTSPOT BREACH" —
 * payload/phase-driven, FR-14), the stadium meter, penalty copy, primary
 * **Show Directions** and secondary **"I Understand"** (closes the current
 * alert only — the dismissal contract, FR-05).
 *
 * Mirrors [com.snabbit.runner.shared.features.job.presentation.newjob.NewJobOverlaySurface]:
 * applies [SnabbitTheme] itself (the native window host can't — the DS isn't
 * on `:app`'s compile classpath); the scrim + window sizing are owned by the
 * host service. Renders nothing unless the coordinator routes `OVERLAY`, so
 * the host's `visible` flow and this content can never disagree (FR-09).
 */
@Composable
fun AwolOverlaySurface(
    viewModel: AwolViewModel,
    modifier: Modifier = Modifier,
    strings: AwolStrings = AwolStrings(),
) {
    SnabbitTheme(darkTheme = false) {
        val state by viewModel.uiState.collectAsState()
        val snapshot = state.snapshot ?: return@SnabbitTheme
        if (state.surface != AwolSurface.OVERLAY) return@SnabbitTheme

        Box(
            modifier = modifier.fillMaxSize(),
            contentAlignment = Alignment.Center,
        ) {
            Column(
                modifier = Modifier
                    .padding(horizontal = 16.dp)
                    .clip(RoundedCornerShape(24.dp))
                    .background(SnabbitTheme.colors.bgPrimary)
                    .padding(16.dp)
                    .verticalScroll(rememberScrollState()),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                AwolAlertContent(
                    state = state,
                    snapshot = snapshot,
                    strings = strings,
                    showBadge = true,
                )
                Column(
                    modifier = Modifier.fillMaxWidth(),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    if (snapshot.hotspot?.hasCoordinates == true) {
                        SnabbitButton(
                            text = strings.showDirections,
                            onClick = { viewModel.onIntent(AwolUiIntent.ShowDirections) },
                            style = SnabbitButtonStyle.Primary,
                            size = SnabbitButtonSize.L,
                            fullWidth = true,
                        )
                    }
                    SnabbitButton(
                        text = strings.understood,
                        onClick = { viewModel.onIntent(AwolUiIntent.Dismiss) },
                        style = SnabbitButtonStyle.NeutralStroke,
                        size = SnabbitButtonSize.L,
                        fullWidth = true,
                    )
                }
            }
        }
    }
}
