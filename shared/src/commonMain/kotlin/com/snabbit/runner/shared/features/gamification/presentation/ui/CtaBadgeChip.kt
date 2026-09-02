package com.snabbit.runner.shared.features.gamification.presentation.ui

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.snabbit.design.atoms.SnabbitRemoteImage
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.theme.SnabbitColorsLight
import com.snabbit.runner.shared.features.gamification.domain.model.CtaOverride
import com.snabbit.runner.shared.resources.Res
import com.snabbit.runner.shared.resources.header_coin
import org.jetbrains.compose.resources.painterResource

/**
 * CDN icon for the red-card pill — Dart `kNudgePillRedCardIconUrl`. There is no
 * correct bundled equivalent (`snabbit_red_card` is the full -50 illustration;
 * `snabbit_red_card_nudge_icon` is actually the No-Show spray-bottle glyph), so
 * the pill loads the same network asset Dart does (Coil-cached).
 */
private const val RED_CARD_PILL_ICON_URL =
    "https://assets-expert.snabbit.com/payouts/nudges/red_card_straight.png"

/**
 * Compact coin / red-card chip shown inline on a gamified CTA button — the KMP
 * port of Dart `lib/widgets/gamification/cta_badge.dart` (Absent chip on Figma
 * 76-38777, Logout chip on 7114:113392). Both variants use a translucent-white
 * fill with a **white** count so they read on the coloured (red-600 / green-600)
 * button they sit on — NOT the standalone red-100/red-600 DS chip.
 *
 * When a [cta] carries both a coin and a red-card badge the **red card wins**
 * (penalty flows), mirroring Dart. Renders nothing when it has neither.
 */
@Composable
fun CtaBadgeChip(
    cta: CtaOverride,
    modifier: Modifier = Modifier,
) {
    val hasCoin = cta.hasCoinBadge
    val hasRed = cta.hasRedCardBadge
    if (!hasCoin && !hasRed) return
    // If BE sends both gold and red on the same CTA, prefer red — mirrors Dart.
    val isCoin = hasCoin && !hasRed
    if (isCoin) CoinPill(cta.goldCoins ?: 0, modifier) else RedCardPill(cta.redCards ?: 0, modifier)
}

/**
 * Red-card pill — matches Dart `_RedCardPill` (lib/widgets/gamification/cta_badge.dart,
 * Figma `7114:113392`): **translucent white (alpha 0.4) fill, red-200 1px border,
 * white count**, radius 999, 16dp icon, gap 4. Vertical padding gives it the
 * design's height.
 */
@Composable
private fun RedCardPill(count: Int, modifier: Modifier) {
    Row(
        modifier = modifier
            .background(SnabbitColorsLight.whiteDefault.copy(alpha = 0.4f), RoundedCornerShape(999.dp))
            .border(1.dp, SnabbitColorsLight.red200, RoundedCornerShape(999.dp))
            .padding(horizontal = 8.dp, vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        SnabbitRemoteImage(
            model = RED_CARD_PILL_ICON_URL,
            contentDescription = null,
            modifier = Modifier.size(16.dp),
            contentScale = ContentScale.Fit,
        )
        SnabbitText(
            text = count.toString(),
            color = SnabbitColorsLight.whiteDefault,
            fontSize = 14.sp,
            lineHeight = 20.sp,
            fontWeight = FontWeight.SemiBold,
        )
    }
}

/**
 * Dart `_CoinPill` (Figma 6705:140052): white@0.2 fill, **no border**, radius 999,
 * horizontal 8 / vertical 2 padding, 14dp icon, 2dp gap, 16sp/SemiBold/white count.
 */
@Composable
private fun CoinPill(count: Int, modifier: Modifier) {
    Row(
        modifier = modifier
            .background(SnabbitColorsLight.whiteDefault.copy(alpha = 0.2f), RoundedCornerShape(999.dp))
            .padding(horizontal = 8.dp, vertical = 2.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        Image(
            painter = painterResource(Res.drawable.header_coin),
            contentDescription = null,
            modifier = Modifier.size(14.dp),
        )
        SnabbitText(
            text = count.toString(),
            color = SnabbitColorsLight.whiteDefault,
            fontSize = 16.sp,
            lineHeight = 24.sp,
            fontWeight = FontWeight.SemiBold,
        )
    }
}
