package com.snabbit.runner.shared.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.jetbrains.compose.ui.tooling.preview.Preview
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.theme.SnabbitTheme

/**
 * SnabbitMetricCard — centered caption + headline value (Expert App component).
 *
 * App-specific composition built on DS primitives (`SnabbitText`). Figma:
 * "Metric Card" component set. Reused by [SnabbitActionFooter] (caption +
 * countdown timer) and [SnabbitEarningsAccordion] (the "You Will Earn" header).
 *
 * [size] picks the typography scale:
 * - [SnabbitMetricCardSize.Md] — caption 12/16, value 44/40 (footer timer)
 * - [SnabbitMetricCardSize.Lg] — caption 16/24, value 64/72 (earnings amount)
 *
 * Colors default to `text.body` (caption) and `text.primary` (value);
 * override [captionColor] / [valueColor] for state coloring (e.g. a green or
 * red countdown).
 *
 * [uppercaseCaption] uppercases the caption (locale-independent) by default;
 * pass `false` to render it as given.
 *
 * [struckValue] renders an original ("was") amount struck-through in
 * `text.tertiary` beside the headline — the earnings-reduced / discounted case
 * (Figma "Earnings change", node 1541:12118). Smaller than the headline (Lg
 * 18sp / Md 14sp) and vertically centered against it.
 */

enum class SnabbitMetricCardSize { Md, Lg }

@Composable
fun SnabbitMetricCard(
    caption: String,
    value: String,
    modifier: Modifier = Modifier,
    size: SnabbitMetricCardSize = SnabbitMetricCardSize.Md,
    captionColor: androidx.compose.ui.graphics.Color = androidx.compose.ui.graphics.Color.Unspecified,
    valueColor: androidx.compose.ui.graphics.Color = androidx.compose.ui.graphics.Color.Unspecified,
    struckValue: String? = null,
    uppercaseCaption: Boolean = true,
) {
    val isLg = size == SnabbitMetricCardSize.Lg
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        SnabbitText(
            text = if (uppercaseCaption) caption.uppercase() else caption,
            color = if (captionColor != androidx.compose.ui.graphics.Color.Unspecified) captionColor else SnabbitTheme.colors.textBody,
            fontSize = if (isLg) 16.sp else 12.sp,
            lineHeight = if (isLg) 24.sp else 16.sp,
            fontWeight = FontWeight.Medium,
            textAlign = TextAlign.Center,
        )
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            SnabbitText(
                text = value,
                color = if (valueColor != androidx.compose.ui.graphics.Color.Unspecified) valueColor else SnabbitTheme.colors.textPrimary,
                fontSize = if (isLg) 64.sp else 44.sp,
                lineHeight = if (isLg) 72.sp else 40.sp,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center,
            )
            if (struckValue != null) {
                SnabbitText(
                    text = struckValue,
                    color = SnabbitTheme.colors.textTertiary,
                    fontSize = if (isLg) 18.sp else 14.sp,
                    lineHeight = if (isLg) 24.sp else 20.sp,
                    fontWeight = FontWeight.Medium,
                    textDecoration = TextDecoration.LineThrough,
                )
            }
        }
    }
}

// ── Previews ──────────────────────────────────────────────────────────

@Preview
@Composable
private fun PreviewSnabbitMetricCard() {
    SnabbitTheme {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(24.dp),
        ) {
            SnabbitMetricCard(caption = "You Will Earn", value = "₹150", size = SnabbitMetricCardSize.Lg)
            SnabbitMetricCard(
                caption = "You Earned",
                value = "₹150",
                size = SnabbitMetricCardSize.Lg,
                valueColor = SnabbitTheme.colors.textSuccess,
            )
            SnabbitMetricCard(caption = "ACCEPT IN", value = "1:23", valueColor = SnabbitTheme.colors.textSuccess)
            SnabbitMetricCard(caption = "ACCEPT IN", value = "00:23", valueColor = SnabbitTheme.colors.textError)
        }
    }
}
