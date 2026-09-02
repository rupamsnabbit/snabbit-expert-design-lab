package com.snabbit.runner.shared.features.awol.presentation.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.features.awol.domain.AwolStrings
import com.snabbit.runner.shared.features.awol.presentation.AwolSurface
import com.snabbit.runner.shared.features.awol.presentation.AwolUiIntent
import com.snabbit.runner.shared.features.awol.presentation.AwolViewModel
import kotlinx.coroutines.flow.StateFlow

/**
 * AwolHomeSection — the complete HOME_CARD surface as the platform-view host
 * embeds it in the Flutter home page: [AwolHomeCard] with [AwolHotspotTile]
 * below (the §2A home mockup pairing). Applies [SnabbitTheme] itself, exactly
 * like [AwolOverlaySurface] — the native host can't (the DS isn't on `:app`'s
 * compile classpath).
 *
 * Composes to zero size unless the coordinator routes `HOME_CARD`, so the
 * host's measured height collapses to 0 on dismissal/clear and the Flutter
 * side needs no separate visibility signal.
 *
 * [distanceText] is the tile's live "3.2 km away" line, produced by
 * [com.snabbit.runner.shared.features.awol.presentation.AwolHotspotDistanceTracker]
 * in the host's scope; the Map action routes to the same Show-Directions
 * effect as the card's CTA (FR-04, one path).
 */
@Composable
fun AwolHomeSection(
    viewModel: AwolViewModel,
    distanceText: StateFlow<String?>,
    modifier: Modifier = Modifier,
    strings: AwolStrings = AwolStrings(),
) {
    SnabbitTheme(darkTheme = false) {
        val state by viewModel.uiState.collectAsState()
        val snapshot = state.snapshot ?: return@SnabbitTheme
        if (state.surface != AwolSurface.HOME_CARD) return@SnabbitTheme

        Column(
            // Bottom gap only when the section actually renders — the home
            // lists compose this slot unconditionally with no spacedBy, so an
            // invisible AWOL section must contribute zero height (ECPO-833 #2).
            modifier = modifier
                .fillMaxWidth()
                .padding(bottom = SnabbitTheme.spacing.layoutGapLg),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            AwolHomeCard(viewModel = viewModel, strings = strings)
            snapshot.hotspot?.let { hotspot ->
                AwolHotspotTile(
                    hotspot = hotspot,
                    strings = strings,
                    onMap = { viewModel.onIntent(AwolUiIntent.ShowDirections) },
                    distanceText = distanceText.collectAsState().value,
                )
            }
        }
    }
}
