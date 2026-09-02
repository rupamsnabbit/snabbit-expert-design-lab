package com.snabbit.runner.shared.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.snabbit.design.atoms.SnabbitCard
import com.snabbit.design.atoms.SnabbitCardPadding
import com.snabbit.design.atoms.SnabbitCardVariant
import com.snabbit.design.atoms.SnabbitImage
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.atoms.SnabbitTextVariant
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.resources.Res
import com.snabbit.runner.shared.resources.hotspot_map_arrow
import com.snabbit.runner.shared.resources.hotspot_pin
import org.jetbrains.compose.resources.painterResource

/**
 * The shared "Your Hotspot" navigation card VISUAL — Figma DS 1491:13181 /
 * 76-31074. Extracted from the home `HotspotNavigationCard` (author: Pallav
 * Karia) so every surface that shows a hotspot tile — the home hotspot card AND
 * the AWOL breach card's tile — renders the identical look.
 *
 * PURELY PRESENTATIONAL and feature-DECOUPLED: it takes plain UI values +
 * callbacks only, never a feature model or intent, so `home` and `awol` each
 * adapt their own data/actions to it without depending on each other.
 *
 *  - [distanceLabel] is the already-formatted "{X} away" text; null hides that row.
 *  - [hotspotName] is hidden when null/blank.
 *  - [showMap] hides the Map chip when there are no coordinates to navigate to.
 *
 * The title stays gray-900 and the distance stays pink-600 in every state —
 * there is no "reached" recolour (product call: the tile reads the same whether
 * or not the runner has arrived).
 */
@Composable
fun SnabbitHotspotCard(
    title: String,
    hotspotName: String?,
    distanceLabel: String?,
    mapLabel: String,
    onBodyClick: () -> Unit,
    onMapClick: () -> Unit,
    modifier: Modifier = Modifier,
    showMap: Boolean = true,
) {
    SnabbitCard(
        modifier = modifier.fillMaxWidth(),
        variant = SnabbitCardVariant.Elevated,
        padding = SnabbitCardPadding.Lg,
        // Elevated reserves headerHeight for the gray strip even with a null header;
        // zero it so the card doesn't ship an empty band (carried from the home card).
        headerHeight = 0.dp,
        onClick = onBodyClick,
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.componentGapMd),
            verticalAlignment = Alignment.Top,
        ) {
            HotspotInfo(
                title = title,
                hotspotName = hotspotName,
                distanceLabel = distanceLabel,
                modifier = Modifier.weight(1f),
            )
            if (showMap) {
                HotspotMapButton(label = mapLabel, onClick = onMapClick)
            }
        }
    }
}

@Composable
private fun HotspotInfo(
    title: String,
    hotspotName: String?,
    distanceLabel: String?,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier,
        verticalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.componentGapSm),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.componentGapSm),
        ) {
            SnabbitImage(
                painter = painterResource(Res.drawable.hotspot_pin),
                contentDescription = null,
                modifier = Modifier.size(16.dp),
                contentScale = ContentScale.Fit,
            )
            SnabbitText(
                text = title,
                variant = SnabbitTextVariant.BodyLg,
                fontWeight = FontWeight.SemiBold,
                color = SnabbitTheme.colors.textPrimary,
            )
        }
        hotspotName?.takeIf { it.isNotBlank() }?.let { name ->
            SnabbitText(
                text = name,
                variant = SnabbitTextVariant.BodyMd,
                fontWeight = FontWeight.Medium,
                color = SnabbitTheme.colors.textBody,
            )
        }
        distanceLabel?.let { distance ->
            SnabbitText(
                text = distance,
                variant = SnabbitTextVariant.Caption,
                fontWeight = FontWeight.Medium,
                color = SnabbitTheme.colors.textBrand,
            )
        }
    }
}

/**
 * The pink Map chip — rounded square with the navigation arrow + "Map" caption
 * below (Figma DS 1581:6929 + 1581:6933). Hand-rolled: the DS ships no square
 * icon-button atom.
 */
@Composable
private fun HotspotMapButton(
    label: String,
    onClick: () -> Unit,
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.componentGapXs),
    ) {
        Box(
            modifier = Modifier
                .clip(RoundedCornerShape(SnabbitTheme.borderRadius.md))
                .background(SnabbitTheme.colors.bgBrandSubtle)
                .clickable(onClick = onClick)
                .padding(SnabbitTheme.spacing.componentGapMd),
            contentAlignment = Alignment.Center,
        ) {
            SnabbitImage(
                painter = painterResource(Res.drawable.hotspot_map_arrow),
                contentDescription = label,
                modifier = Modifier.size(17.dp),
                contentScale = ContentScale.Fit,
            )
        }
        SnabbitText(
            text = label,
            variant = SnabbitTextVariant.Caption,
            color = SnabbitTheme.colors.textSecondary,
        )
    }
}
