package com.snabbit.runner.shared.features.gamification.presentation.ui

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.theme.SnabbitColorsLight
import com.snabbit.runner.shared.features.gamification.domain.model.NudgePill
import com.snabbit.runner.shared.features.gamification.domain.model.NudgePillKind
import com.snabbit.runner.shared.resources.Res
import com.snabbit.runner.shared.resources.header_coin
import com.snabbit.runner.shared.resources.snabbit_red_card
import org.jetbrains.compose.resources.painterResource

/**
 * Trailing coin / red-card count pill for a nudge strip — the KMP port of Dart
 * `lib/widgets/gamification/nudge_pill_badge.dart`. Renders nothing when the pill
 * is [NudgePillKind.None] or the count is 0.
 *
 * Uses the **bundled** coin / red-card drawables rather than the Dart CDN icons
 * (`gold_coin.png` / `red_card_straight.png`) so both platforms render without a
 * network round-trip.
 */
@Composable
fun NudgePillBadge(
    pill: NudgePill,
    modifier: Modifier = Modifier,
) {
    if (!pill.hasPill) return
    val isCoin = pill.kind == NudgePillKind.Coin
    val bg = if (isCoin) SnabbitColorsLight.yellow100 else SnabbitColorsLight.red100
    val fg = if (isCoin) SnabbitColorsLight.yellow600 else SnabbitColorsLight.red600
    val icon = if (isCoin) Res.drawable.header_coin else Res.drawable.snabbit_red_card

    Row(
        modifier = modifier
            .background(bg, RoundedCornerShape(999.dp))
            .padding(horizontal = 8.dp, vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Image(
            painter = painterResource(icon),
            contentDescription = null,
            modifier = Modifier.height(16.dp),
        )
        SnabbitText(
            text = pill.count.toString(),
            color = fg,
            fontSize = 14.sp,
            lineHeight = 18.sp,
            fontWeight = FontWeight.SemiBold,
        )
    }
}
