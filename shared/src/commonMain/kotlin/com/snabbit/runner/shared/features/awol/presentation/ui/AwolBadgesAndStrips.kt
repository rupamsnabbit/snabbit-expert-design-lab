package com.snabbit.runner.shared.features.awol.presentation.ui

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.snabbit.design.atoms.SnabbitImage
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.atoms.SnabbitTextVariant
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.features.awol.domain.AwolPhase
import com.snabbit.runner.shared.features.awol.domain.AwolStrings
import com.snabbit.runner.shared.resources.Res
import com.snabbit.runner.shared.resources.snabbit_late_clock
import com.snabbit.runner.shared.resources.snabbit_red_card_icon
import org.jetbrains.compose.resources.painterResource

/**
 * The §2A status badge pill ("MOVEMENT REQUIRED" / "HOTSPOT BREACH" /
 * "BACK IN HOTSPOT") shown on the overlay card. Fresh mockup element —
 * hand-rolled pill (the SnabbitRedCardNudge approach) with DS text; colours
 * are payload/phase-driven theme tokens (FR-14).
 */
@Composable
fun AwolBadge(
    text: String,
    phase: AwolPhase,
    modifier: Modifier = Modifier,
) {
    val accent = awolAccent(phase)
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(50))
            .background(awolContainer(phase))
            .padding(horizontal = 12.dp, vertical = 4.dp),
    ) {
        SnabbitText(
            text = text,
            // 14/Medium/20 center (design spec): no DS 14-Medium variant, so BodyMd
            // (14/20) + a per-call Medium weight.
            variant = SnabbitTextVariant.BodyMd,
            fontWeight = FontWeight.Medium,
            textAlign = TextAlign.Center,
            color = accent,
        )
    }
}

/**
 * The §2A red-card pill ("1 Red Card Received") shown above the title once
 * cards are held (FR-07). Hidden by the caller when [count] is 0. The label
 * MUST resolve singular/plural — "1 Red Card", never "1 Red Cards"
 * (§2A; [AwolStrings.redCardReceivedLabel] is the single source of truth,
 * parity with the Dart `redCardReceivedLabel`). Renders the same
 * `snabbit_red_card_icon` glyph the penalty-rate strip uses, so the two agree.
 */
@Composable
fun AwolRedCardPill(
    count: Int,
    strings: AwolStrings,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier
            .clip(RoundedCornerShape(50))
            .background(SnabbitTheme.colors.bgErrorSubtle)
            .padding(horizontal = 12.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        // Same red-card glyph the penalty-rate strip uses, so the two agree (issue 3).
        SnabbitImage(
            painter = painterResource(Res.drawable.snabbit_red_card_icon),
            contentDescription = null,
            modifier = Modifier.height(16.dp),
            contentScale = ContentScale.Fit,
        )
        SnabbitText(
            text = "$count ${strings.redCardReceivedLabel(count)}",
            // 14/Medium/20 center (design spec) — matches the AwolBadge it replaces.
            variant = SnabbitTextVariant.BodyMd,
            fontWeight = FontWeight.Medium,
            textAlign = TextAlign.Center,
            color = SnabbitTheme.colors.textError,
        )
    }
}

/**
 * The §2A penalty-rate strip — a dash-bordered band under the warning text with
 * the ❗ alert badge straddling its top border. The fixed cadence renders as two
 * red capsules with raster glyphs — "[count] 🟥" · [connector] · "[interval] ⏰"
 * (e.g. "1 red-card for every 15 Minutes clock", Figma §2A). The pieces come from
 * [AwolStrings]; the caller shows the strip only when the snapshot carries a
 * penalty rate (BREACH, FR-03).
 *
 * The badge is a solid accent disc with a white "!" (the card's [bgPrimary]),
 * straddling the border.
 */
@Composable
fun AwolPenaltyRateStrip(
    count: String,
    connector: String,
    interval: String,
    modifier: Modifier = Modifier,
) {
    val accent = SnabbitTheme.colors.textError
    val dash = PathEffect.dashPathEffect(floatArrayOf(10f, 8f))
    Box(
        modifier = modifier.fillMaxWidth(),
        contentAlignment = Alignment.TopCenter,
    ) {
        Row(
            // Top padding clears the overhanging badge; the dashed border is
            // drawn below it, so the badge straddles the border line.
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 10.dp)
                .drawBehind {
                    drawRoundRect(
                        color = accent,
                        cornerRadius = CornerRadius(12.dp.toPx()),
                        style = Stroke(width = 1.dp.toPx(), pathEffect = dash),
                    )
                }
                .padding(horizontal = 16.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally),
        ) {
            PenaltyCapsule(text = count) {
                Image(
                    painter = painterResource(Res.drawable.snabbit_red_card_icon),
                    contentDescription = null,
                    modifier = Modifier.height(16.dp),
                    contentScale = ContentScale.Fit,
                )
            }
            SnabbitText(
                text = connector,
                // 12/Medium/16: no DS 12-Medium variant, so override the weight per-call.
                variant = SnabbitTextVariant.Caption,
                fontWeight = FontWeight.Medium,
                // Connector ("for every") is ink, not error-red like the capsules/border —
                // textPrimary is the DS token for #111827 (see SnabbitColorsLight.gray900).
                color = SnabbitTheme.colors.textPrimary,
            )
            PenaltyCapsule(text = interval) {
                Image(
                    painter = painterResource(Res.drawable.snabbit_late_clock),
                    contentDescription = null,
                    modifier = Modifier.size(16.dp),
                    contentScale = ContentScale.Fit,
                )
            }
        }
        Box(
            modifier = Modifier
                .size(20.dp)
                .clip(CircleShape)
                .background(accent),
            contentAlignment = Alignment.Center,
        ) {
            SnabbitText(
                text = "!",
                variant = SnabbitTextVariant.Caption,
                color = SnabbitTheme.colors.bgPrimary,
            )
        }
    }
}

/**
 * A single red pill inside [AwolPenaltyRateStrip]: [text] followed by a trailing
 * raster [glyph], on the subtle-error fill (parity with [AwolRedCardPill]).
 */
@Composable
private fun PenaltyCapsule(
    text: String,
    glyph: @Composable () -> Unit,
) {
    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(50))
            .background(SnabbitTheme.colors.bgErrorSubtle)
            .padding(horizontal = 10.dp, vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        SnabbitText(
            text = text,
            // 12/Medium/16: no DS 12-Medium variant, so override the weight per-call.
            variant = SnabbitTextVariant.Caption,
            fontWeight = FontWeight.Medium,
            color = SnabbitTheme.colors.textError,
        )
        glyph()
    }
}
