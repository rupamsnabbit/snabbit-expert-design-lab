package com.snabbit.runner.shared.features.job.delayedcheckin.presentation

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.atoms.SnabbitToast
import com.snabbit.design.atoms.SnabbitToastVariant
import com.snabbit.design.theme.SnabbitColorsLight
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.features.job.delayedcheckin.domain.model.PenaltyNudge
import com.snabbit.runner.shared.ui.nudges.SnabbitRedCardNudge
import com.snabbit.runner.shared.resources.Res
import com.snabbit.runner.shared.resources.snabbit_red_card
import com.snabbit.runner.shared.resources.snabbit_red_card_icon
import com.snabbit.runner.shared.resources.snabbit_red_card_nudge_icon
import org.jetbrains.compose.resources.painterResource
import org.jetbrains.compose.ui.tooling.preview.Preview

/**
 * The **"N Red Card(s) Received"** counter pill at the top of the penalty
 * section — the Dart "top red card pill" (`delayed_checkin_penalty_widget.dart`,
 * rendered whenever a penalty countdown is active, **including at zero** —
 * `NudgePillBadge` has no zero-suppression; callers gate on the countdown,
 * not the count). Full-pill red50/red500 presentation with the red-card glyph
 * leading, per the Figma spec — see the in-body note on why this composes the
 * DS palette directly instead of using the SnabbitTag atom.
 */
@Composable
fun RedCardCounterChip(
    receivedRedCards: Int,
    strings: DelayedCheckinStrings,
    modifier: Modifier = Modifier,
) {
    val suffix = if (receivedRedCards == 1) strings.redCardReceived else strings.redCardsReceived
    // Figma spec: red50 (#FEF2F2) pill, red500 (#EF4444) text, radius 100 (full
    // pill). SnabbitTag's fixed Soft/Error matrix is red100/red700 with a
    // size-token radius, so the pill is composed here from the same DS palette —
    // the SnabbitActionFooter-wash flagged deviation; a custom-colors SnabbitTag
    // variant would let this go back to the DS atom.
    Row(
        modifier = modifier
            .clip(RoundedCornerShape(100.dp))
            .background(SnabbitColorsLight.red50)
            .padding(horizontal = 16.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Image(
            // The plain card glyph (no "−50") — the −50 artwork stays exclusive
            // to the deduction banner's card stack.
            painter = painterResource(Res.drawable.snabbit_red_card_icon),
            contentDescription = null,
            modifier = Modifier.size(14.dp),
        )
        SnabbitText(
            text = "$receivedRedCards $suffix",
            color = SnabbitColorsLight.red500,
            fontSize = 13.sp,
            fontWeight = FontWeight.Medium,
        )
    }
}

/**
 * The **"X red card will be added"** deduction banner between the counter
 * pill and the customer card — Dart parity `_buildNudgeStrip`
 * (`delayed_checkin_penalty_widget.dart`: `NudgeStripTile` risk theme +
 * trailing red-card visual), fed from the widget's `pre_action_nudges`
 * entry. Renders as [SnabbitRedCardNudge] (Figma 1051:50911): the "−50" cards
 * poke above the pill's top-right corner, one per card the next step adds
 * (max 7 drawn); from 3 the fan compresses so any count keeps the 2-card
 * footprint.
 */
@Composable
fun PenaltyNudgeBanner(
    nudge: PenaltyNudge,
    modifier: Modifier = Modifier,
) {
    // The DS red-card nudge IS this banner (Figma 1051:50911 = Component 15):
    // gradient pill + disc icon + the tilted card stack poking over the
    // top-right corner. Only the label and card count are BE-driven.
    SnabbitRedCardNudge(
        modifier = modifier,
        text = nudge.label,
        cardCount = nudge.redCards ?: 1,
    )
}

/**
 * The penalty flow's transient feedback banner — the [DelayedCheckinEffect.Toast]
 * render surface: **green** ([SnabbitToastVariant.Success]) for the Ameyo
 * "call back soon" confirmation, **red** for submit/config errors. Same
 * top-aligned DS toast + auto-dismiss contract as `JobActionToast` (the
 * accept/deny sibling); [onShown] clears the one-shot so it doesn't
 * re-appear on recomposition.
 */
@Composable
fun BoxScope.DelayedCheckinToast(
    toast: DelayedCheckinEffect.Toast?,
    onShown: () -> Unit,
) {
    if (toast == null) return
    SnabbitToast(
        title = toast.message,
        variant = if (toast.success) SnabbitToastVariant.Success else SnabbitToastVariant.Error,
        durationMillis = TOAST_DURATION_MILLIS,
        onDismiss = onShown,
        modifier = Modifier
            .align(Alignment.TopCenter)
            .fillMaxWidth()
            .padding(16.dp),
    )
}

/** Auto-dismiss window — matches `JobActionToast`. */
private const val TOAST_DURATION_MILLIS = 4000L

/* ── Previews ────────────────────────────────────────────────────────── */

@Preview
@Composable
private fun PreviewRedCardCounterChipSingular() {
    SnabbitTheme {
        RedCardCounterChip(receivedRedCards = 1, strings = DelayedCheckinStrings())
    }
}

@Preview
@Composable
private fun PreviewRedCardCounterChipPlural() {
    SnabbitTheme {
        RedCardCounterChip(receivedRedCards = 2, strings = DelayedCheckinStrings())
    }
}

@Preview
@Composable
private fun PreviewPenaltyNudgeBannerOneCard() {
    SnabbitTheme {
        PenaltyNudgeBanner(nudge = PenaltyNudge(label = "1 red card will be added", redCards = 1))
    }
}

@Preview
@Composable
private fun PreviewPenaltyNudgeBannerTwoCards() {
    SnabbitTheme {
        PenaltyNudgeBanner(nudge = PenaltyNudge(label = "2 red cards will be added", redCards = 2))
    }
}
