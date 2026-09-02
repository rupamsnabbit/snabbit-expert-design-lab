package com.snabbit.runner.shared.features.awol.presentation.ui

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.layout.Arrangement
import com.snabbit.design.atoms.SnabbitButton
import com.snabbit.design.atoms.SnabbitButtonSize
import com.snabbit.design.atoms.SnabbitButtonStyle
import com.snabbit.design.atoms.SnabbitCard
import com.snabbit.design.atoms.SnabbitCardLayout
import com.snabbit.design.atoms.SnabbitCardPadding
import com.snabbit.design.atoms.SnabbitCardVariant
import com.snabbit.runner.shared.features.awol.domain.AwolStrings
import com.snabbit.runner.shared.features.awol.presentation.AwolSurface
import com.snabbit.runner.shared.features.awol.presentation.AwolUiIntent
import com.snabbit.runner.shared.features.awol.presentation.AwolViewModel

/**
 * AwolHomeCard — the in-app surface (§9 routing: `HOME_CARD`), embedded in
 * the home page and persistent while the awol object is present (FR-01..04,
 * §2A "Home card" mockup): image, red-card pill when held, title, stadium
 * meter, warning, penalty-rate strip, single **Show Directions** CTA
 * (coordinates-gated). Pair with [AwolHotspotTile] below it on the home page.
 *
 * Renders nothing unless the coordinator routes here — exactly one surface
 * alerts at a time (FR-09). Observes the process-lived [AwolViewModel]
 * (Koin single); the host only places this composable.
 */
@Composable
fun AwolHomeCard(
    viewModel: AwolViewModel,
    modifier: Modifier = Modifier,
    strings: AwolStrings = AwolStrings(),
) {
    val state by viewModel.uiState.collectAsState()
    val snapshot = state.snapshot ?: return
    if (state.surface != AwolSurface.HOME_CARD) return

    SnabbitCard(
        modifier = modifier.fillMaxWidth(),
        variant = SnabbitCardVariant.Base,
        padding = SnabbitCardPadding.Lg,
        layout = SnabbitCardLayout.Block,
    ) {
        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            AwolAlertContent(
                state = state,
                snapshot = snapshot,
                strings = strings,
                // Show the phase status badge on the home card too ("HOTSPOT BREACH" /
                // "MOVEMENT REQUIRED" for job-AWOL / "BACK IN HOTSPOT"), matching the
                // overlay — the badge is the surface's at-a-glance state cue.
                showBadge = true,
            )
            if (snapshot.hotspot?.hasCoordinates == true) {
                SnabbitButton(
                    text = strings.showDirections,
                    onClick = { viewModel.onIntent(AwolUiIntent.ShowDirections) },
                    style = SnabbitButtonStyle.Primary,
                    size = SnabbitButtonSize.L,
                    fullWidth = true,
                )
            }
        }
    }
}
