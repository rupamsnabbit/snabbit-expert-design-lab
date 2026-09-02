package com.snabbit.runner.shared.ui.nudges

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import org.jetbrains.compose.resources.painterResource
import org.jetbrains.compose.ui.tooling.preview.Preview
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.resources.Res
import com.snabbit.runner.shared.resources.snabbit_red_card

/** Aspect ratio (width / height) of the red-card illustration — matches the bundled 3× asset (197 × 288). */
private const val RedCardAspectRatio = 197f / 288f

/**
 * SnabbitRedCard — the gamification **red card** penalty illustration (Figma node
 * `758:4746`, the tight "red card" reading "-50").
 *
 * A raster **illustration** ([Res.drawable.snabbit_red_card], "-50" baked in) — no DS
 * component composes it (flagged per the DS-only rule). Sized by [height]; the width
 * follows the card's [RedCardAspectRatio], so the tight artwork fills the bounds with
 * no letterbox padding. Group multiple via [SnabbitRedCardGroup].
 */
@Composable
fun SnabbitRedCard(
    modifier: Modifier = Modifier,
    height: Dp = SnabbitRedCardDefaults.Height,
    contentDescription: String? = null,
) {
    Image(
        painter = painterResource(Res.drawable.snabbit_red_card),
        contentDescription = contentDescription,
        modifier = modifier.height(height).aspectRatio(RedCardAspectRatio),
        contentScale = ContentScale.Fit,
    )
}

/**
 * SnabbitRedCardGroup — [count] overlapping [SnabbitRedCard]s, fanned like a deck
 * (Figma `758:4942` = 2, `758:4941` = 3). Each card overlaps the next by
 * [SnabbitRedCardDefaults.OverlapRatio] of its width; the rightmost draws on top.
 */
@Composable
fun SnabbitRedCardGroup(
    count: Int,
    modifier: Modifier = Modifier,
    cardHeight: Dp = SnabbitRedCardDefaults.Height,
) {
    val overlap = cardHeight * RedCardAspectRatio * SnabbitRedCardDefaults.OverlapRatio
    Row(
        modifier = modifier,
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(-overlap),
    ) {
        repeat(count) {
            SnabbitRedCard(height = cardHeight)
        }
    }
}

/**
 * Per-card horizontal offset (dp) for a multi red-card fan: up to 2 cards sit
 * side by side, near-fully visible (Figma 939:54144); from 3 the step compresses
 * (`34 / (shown - 1)`) so any count keeps the 2-card footprint — the larger the
 * number, the closer the cards stack above each other (Figma 939:54156).
 * Callers clamp `shown` to the 7-card max first.
 */
fun redCardFanStep(shown: Int): Float =
    if (shown <= 2) SIDE_BY_SIDE_STEP_DP else SIDE_BY_SIDE_STEP_DP / (shown - 1)

/** ~83% of the 41dp card width — two cards read side by side with a sliver of overlap. */
private const val SIDE_BY_SIDE_STEP_DP = 34f

/** Shared defaults for the red-card illustration. */
object SnabbitRedCardDefaults {
    /** Natural height of the tight red-card illustration (Figma 758:4746). */
    val Height: Dp = 96.dp

    /** Deck overlap between grouped cards, as a fraction of card width. */
    const val OverlapRatio: Float = 0.35f
}

/* ── Previews ────────────────────────────────────────────────────────── */

@Preview
@Composable
private fun PreviewSnabbitRedCard() {
    SnabbitTheme {
        Column(modifier = Modifier.padding(16.dp)) {
            SnabbitRedCard()
        }
    }
}

@Preview
@Composable
private fun PreviewSnabbitRedCardGroups() {
    SnabbitTheme {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            SnabbitRedCardGroup(count = 1)
            SnabbitRedCardGroup(count = 2)
            SnabbitRedCardGroup(count = 3)
        }
    }
}

