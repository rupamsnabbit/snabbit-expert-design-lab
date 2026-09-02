package com.snabbit.runner.shared.features.home.presentation.ui.sheets

import com.snabbit.design.atoms.SnabbitImage
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.dp
import com.snabbit.runner.shared.resources.Res
import com.snabbit.runner.shared.resources.red_card_display
import org.jetbrains.compose.resources.painterResource

/**
 * Red-card cluster used in [ChangeAttendanceConfirmSheet] and [WaiverSheet].
 *
 * Renders [count] copies of the Dart `RedCardIllustration`
 * (`lib/widgets/gamification/shared_red_card_widgets.dart` →
 * `SingleRedCard`), which itself loads
 * `https://assets-expert.snabbit.com/payouts/nudges/red_card_display.png`.
 * That PNG is bundled into commonMain compose-resources as
 * [Res.drawable.red_card_display] so both platforms render the exact same
 * asset (no network round-trip on the runner's device either).
 *
 * Geometry mirrors Dart:
 *  - Card: 69 × 98 dp.
 *  - Horizontal padding 5 dp per side → 10 dp gap between cards.
 *  - [faded] = true tints the row to 40% opacity (Waiver sheet's
 *    pink-tinted waived state, Figma 1597:6691).
 */
@Composable
internal fun RedCardClusterPlaceholder(count: Int, faded: Boolean) {
    val painter = painterResource(Res.drawable.red_card_display)
    Row(
        modifier = Modifier
            .height(98.dp)
            .alpha(if (faded) 0.4f else 1f),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        repeat(count.coerceIn(1, 9)) {
            SnabbitImage(
                painter = painter,
                contentDescription = null,
                modifier = Modifier.size(width = 69.dp, height = 98.dp),
                contentScale = ContentScale.Fit,
            )
        }
    }
}
