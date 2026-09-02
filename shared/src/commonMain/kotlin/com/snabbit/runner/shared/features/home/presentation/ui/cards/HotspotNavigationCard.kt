package com.snabbit.runner.shared.features.home.presentation.ui.cards

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.snabbit.runner.shared.features.home.domain.model.HomeCard
import com.snabbit.runner.shared.features.home.presentation.HomeStrings
import com.snabbit.runner.shared.features.home.presentation.HomeUiIntent
import com.snabbit.runner.shared.ui.components.SnabbitHotspotCard

/**
 * Hotspot navigation card — Figma DS 1491:13181 ("Hotspot" state),
 * sub-states from DS 76-31074 ("Your Hotspot" / "You have Reached").
 *
 * Feature adapter: maps [HomeCard.ShiftLogin] + [HomeStrings] onto the shared,
 * purely-presentational [SnabbitHotspotCard] so the home tile and the AWOL
 * breach tile render the identical look. Title stays gray "Your Hotspot" and
 * distance stays pink "{distance} away" regardless of [HomeCard.ShiftLogin.reached].
 *
 * Body and Map fire distinct intents ([HomeUiIntent.TapHotspot] vs
 * [HomeUiIntent.TapHotspotMap]) so analytics can tell the two entry points
 * apart; the Map chip's own `clickable` consumes the gesture so taps on it
 * don't double-fire the body click.
 *
 * ponytail: photo strip from DS variant skipped per product call. canLoginNow
 * rides on the card data but has no UI consumer here — the login CTA lives
 * on the TL/OTP card (DS frame 2147243437), next slice.
 */
@Composable
fun HotspotNavigationCard(
    card: HomeCard.ShiftLogin,
    strings: HomeStrings,
    onIntent: (HomeUiIntent) -> Unit,
    modifier: Modifier = Modifier,
) {
    SnabbitHotspotCard(
        title = strings.hotspotTitleNotReached,
        hotspotName = card.hotspotName,
        distanceLabel = card.distanceLabel?.let {
            strings.hotspotDistanceTemplate.replace("{distance}", it)
        },
        mapLabel = strings.hotspotMapLabel,
        onBodyClick = { onIntent(HomeUiIntent.TapHotspot(card.lat, card.lng)) },
        onMapClick = { onIntent(HomeUiIntent.TapHotspotMap(card.lat, card.lng)) },
        modifier = modifier,
        // Map chip is always shown (default): with null coords TapHotspotMap
        // no-ops downstream rather than opening a bad location, per the
        // HomeCard.ShiftLogin.lat/lng contract — preserving the original card's UX.
    )
}
