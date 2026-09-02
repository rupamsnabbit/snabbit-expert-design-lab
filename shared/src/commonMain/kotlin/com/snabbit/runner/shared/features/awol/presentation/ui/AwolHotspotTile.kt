package com.snabbit.runner.shared.features.awol.presentation.ui

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.snabbit.runner.shared.features.awol.domain.AwolHotspot
import com.snabbit.runner.shared.features.awol.domain.AwolStrings
import com.snabbit.runner.shared.ui.components.SnabbitHotspotCard

/**
 * The §2A "Your Hotspot · 3.2 km away · Map" home tile — the AWOL breach
 * surface's hotspot tile.
 *
 * Feature adapter: maps [AwolHotspot] + [AwolStrings] onto the shared,
 * purely-presentational [SnabbitHotspotCard] so this tile and the home hotspot
 * card render the identical look. [distanceText] (e.g. "3.2 km away") is
 * optional — the row hides it when the runner's location isn't available. The
 * Map chip fires [onMap] (routed to the Show-Directions effect, FR-04) and is
 * shown only when the hotspot has coordinates.
 */
@Composable
fun AwolHotspotTile(
    hotspot: AwolHotspot,
    strings: AwolStrings,
    onMap: () -> Unit,
    modifier: Modifier = Modifier,
    distanceText: String? = null,
) {
    SnabbitHotspotCard(
        title = strings.hotspotTileTitle,
        hotspotName = hotspot.name,
        distanceLabel = distanceText,
        mapLabel = strings.hotspotTileMap,
        onBodyClick = onMap,
        onMapClick = onMap,
        modifier = modifier,
        showMap = hotspot.hasCoordinates,
    )
}
