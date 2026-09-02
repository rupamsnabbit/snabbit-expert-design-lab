package com.snabbit.runner.shared.ui.nudges

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.jetbrains.compose.resources.painterResource
import org.jetbrains.compose.ui.tooling.preview.Preview
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.theme.SnabbitColorsLight
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.resources.Res
import com.snabbit.runner.shared.resources.snabbit_red_card_nudge_icon

/**
 * SnabbitRedCardNudge — the red-card warning nudge for the new-job acceptance screen
 * (Figma node `1535:11788`): a pill with a **gray-50 → red-200 horizontal gradient**,
 * a 1.5dp red-200 border and 12dp radius, holding a leading category icon + [text]
 * (default the Figma copy "If job not accepted"), with a [SnabbitRedCard] tilted and
 * poking above the pill on the right — the penalty the runner incurs if they don't accept.
 *
 * Tokens: gray-50 → [SnabbitTheme.colors.bgSecondary], red-200 → [SnabbitColorsLight.red200],
 * gray-700 text → [SnabbitColorsLight.gray700]. The leading icon is a bundled illustration
 * ([Res.drawable.snabbit_red_card_nudge_icon]); the design's decorative red ellipses are
 * approximated by the gradient.
 */
@Composable
fun SnabbitRedCardNudge(
    modifier: Modifier = Modifier,
    text: String = "If job not accepted",
    // Cards in the tilted stack poking over the pill (Figma 1051:50911): at most 7
    // drawn; 1–2 fan at the full 18dp offset, from 3 the offsets compress
    // ([redCardFanStep]) so any count keeps the 2-card footprint.
    cardCount: Int = 1,
) {
    val red200 = SnabbitColorsLight.red200
    val gray50 = SnabbitTheme.colors.bgSecondary
    val pillShape = RoundedCornerShape(12.dp)

    Box(modifier = modifier.fillMaxWidth().height(72.dp)) {
        // Gradient pill — bottom-aligned so the red card can poke above its top edge.
        Box(
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .fillMaxWidth()
                .height(56.dp)
                .clip(pillShape)
                .background(Brush.horizontalGradient(listOf(gray50, red200)))
                .border(1.5.dp, red200, pillShape),
        ) {
            Row(
                modifier = Modifier
                    .align(Alignment.CenterStart)
                    // The right inset reserves the corner for the card stack — two
                    // side-by-side cards (Figma 939:54144) need the wider clearing.
                    .padding(start = 12.dp, end = if (cardCount > 1) 104.dp else 88.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Image(
                    painter = painterResource(Res.drawable.snabbit_red_card_nudge_icon),
                    contentDescription = null,
                    modifier = Modifier.size(32.dp),
                )
                SnabbitText(
                    text = text,
                    color = SnabbitColorsLight.gray700,
                    fontSize = 16.sp,
                    lineHeight = 24.sp,
                    fontWeight = FontWeight.Normal,
                    // The pill is fixed-height and the right inset is reserved for the tilted red
                    // card, so a longer / localized string ellipsizes rather than clipping.
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }

        // Red cards tilted on the right, poking above the pill (Figma ~7.5°) —
        // every card shares the tilt, later cards draw on top; the fan step
        // compresses past 2 so the stack keeps the 2-card footprint.
        val shown = cardCount.coerceIn(1, 7)
        val step = redCardFanStep(shown)
        Box(Modifier.align(Alignment.TopEnd).padding(end = 20.dp)) {
            repeat(shown) { index ->
                SnabbitRedCard(
                    height = 60.dp,
                    modifier = Modifier
                        .padding(start = (index * step).dp)
                        .graphicsLayer { rotationZ = 7.52f },
                )
            }
        }
    }
}

/* ── Previews ────────────────────────────────────────────────────────── */

@Preview
@Composable
private fun PreviewSnabbitRedCardNudge() {
    SnabbitTheme {
        Column(modifier = Modifier.padding(16.dp)) {
            SnabbitRedCardNudge()
        }
    }
}
