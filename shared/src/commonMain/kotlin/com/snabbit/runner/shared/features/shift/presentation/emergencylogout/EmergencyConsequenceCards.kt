package com.snabbit.runner.shared.features.shift.presentation.emergencylogout
import com.snabbit.design.atoms.SnabbitImage
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.atoms.SnabbitTextVariant
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.resources.Res
import com.snabbit.runner.shared.resources.full_shift_card
import com.snabbit.runner.shared.resources.red_card_display
import com.snabbit.runner.shared.resources.earnings_loss_bs_icon
import org.jetbrains.compose.resources.painterResource

/**
 * The "Emergency logout will lead to" consequence trio (Figma 222:45683 /
 * 220:38847): Red Card + Miss Full Shift + (optionally) "Lose ₹X".
 *
 * Red Card + Miss Full Shift use the SAME PNGs Dart loads remotely
 * (`red_card_display.png`, `full_shift_card.png`); the earnings tile uses the
 * expert-v2 `earnings_loss_bs_icon.png` (Figma 222:39955) rather than Dart's
 * `rupee_circle` — that one is still in use by `TomorrowProvisionalCard`. All are
 * bundled into `composeResources/drawable/` so the screen renders synchronously.
 *
 * Layout follows Figma 222:41197 exactly for the three-tile case: 80×80 art box,
 * 10dp art→label gap, `SpaceBetween` inside 20dp side padding. The design only ever
 * draws three tiles, so shorter rows (Red Card and/or the earnings tile absent) fall
 * back to `SpaceEvenly` — otherwise a lone tile is pinned against the left padding.
 *
 * Gamification wiring (KMP gamification port): [redCardCount] is the real
 * decoded `cta_overrides[logout].red_cards`; [earningLossLabel] renders the
 * previously-deferred "Lose ₹X" tile when the server provides an already-formatted
 * amount (e.g. "₹250"), null hides it.
 *
 * Period-leave parity with Dart: when [periodLeaveSelected] is true, the Red Card
 * tile hides (period leave waives that penalty); Miss Full Shift stays. The Red
 * Card tile also hides whenever [redCardCount] is 0 — there is no default card;
 * it only renders what the BE explicitly sends (Dart parity).
 */
@Composable
fun EmergencyConsequenceCards(
    redCardCount: Int,
    periodLeaveSelected: Boolean,
    modifier: Modifier = Modifier,
    strings: EmergencyLogoutStrings = rememberEmergencyLogoutStrings(),
    earningLossLabel: String? = null,
) {
    // Resolved up front so the arrangement can depend on how many tiles actually
    // render — Miss Full Shift is the only unconditional one.
    val tiles = buildList {
        if (redCardCount > 0 && !periodLeaveSelected) {
            add(strings.redCardLabelTemplate.replace("{count}", redCardCount.toString()) to Res.drawable.red_card_display)
        }
        add(strings.missShiftLabel to Res.drawable.full_shift_card)
        if (earningLossLabel != null) {
            add(strings.loseEarningsTemplate.replace("₹{amount}", earningLossLabel) to Res.drawable.earnings_loss_bs_icon)
        }
    }

    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = SnabbitTheme.spacing.`6`),
        // Figma 222:39921 specs `justify-between` inside 20dp side padding, but only
        // ever draws three tiles. SpaceBetween on a shorter row pins the survivors to
        // the edges — with a single tile (no red cards *and* no earning loss, i.e. what
        // the BE sends today) it lands hard against the left padding. Centre those
        // instead; SpaceEvenly centres one tile and balances two.
        horizontalArrangement = if (tiles.size >= 3) {
            Arrangement.SpaceBetween
        } else {
            Arrangement.SpaceEvenly
        },
    ) {
        tiles.forEach { (label, art) ->
            ConsequenceTile(label = label, imagePainter = painterResource(art))
        }
    }
}

@Composable
private fun ConsequenceTile(
    label: String,
    imagePainter: androidx.compose.ui.graphics.painter.Painter,
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        // Figma art→label gap is 10dp; the DS spacing scale jumps 8 (`3`) → 12 (`4`),
        // so there's no token for it. Raw dp keeps the tile pixel-accurate.
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        SnabbitImage(
            painter = imagePainter,
            contentDescription = null,
            // Figma 222:39923/39937/39955 — every tile's art sits in an 80×80 square box
            // (the art itself is smaller and centred, hence ContentScale.Fit).
            modifier = Modifier.size(80.dp),
            contentScale = ContentScale.Fit,
        )
        SnabbitText(
            text = label,
            // Figma 222:45683 tiles — Body-M/16-Medium on gray-700.
            variant = SnabbitTextVariant.BodyLg,
            fontWeight = FontWeight.Medium,
            color = SnabbitTheme.colors.textBody,
            textAlign = TextAlign.Center,
        )
    }
}
