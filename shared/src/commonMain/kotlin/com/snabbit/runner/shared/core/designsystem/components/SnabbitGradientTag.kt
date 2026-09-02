package com.snabbit.runner.shared.core.designsystem.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.atoms.SnabbitTextVariant
import com.snabbit.design.theme.SnabbitTheme

/**
 * Tag pill with a **gradient** background and an optional **border ring**.
 *
 * Extension of `SnabbitTag`: mirrors its pill shape, padding, and typography
 * contract using DS atoms (`SnabbitText` for the label) but adds the two
 * visuals `SnabbitTag` cannot express today — a gradient fill, and a ring
 * border that is independent of `tagStyle`.
 *
 * ponytail: anticipates an upstream `SnabbitTag(tagStyle = Gradient, border = ...)`.
 * When that lands, every call site here moves to `SnabbitTag(...)` with no
 * behaviour change — keep the same default size/padding so swapping is a
 * find-and-replace.
 */
@Composable
fun SnabbitGradientTag(
    text: String,
    background: Brush,
    textColor: Color,
    modifier: Modifier = Modifier,
    borderColor: Color? = null,
) {
    val shape = RoundedCornerShape(SnabbitTheme.borderRadius.full)
    val borderMod = if (borderColor != null) {
        Modifier.border(1.5.dp, borderColor, shape)
    } else {
        Modifier
    }
    Box(
        modifier = modifier
            .clip(shape)
            .background(background, shape)
            .then(borderMod)
            // Matches SnabbitTag.Size.S padding so the pill aligns with other
            // DS tags in a row.
            .padding(horizontal = 8.dp, vertical = 2.dp),
    ) {
        // Figma chip text: Outfit/SemiBold/12/14. Caption is 12/Normal; weight
        // overridden until DS adds a `CaptionSemibold` variant.
        SnabbitText(
            text = text,
            variant = SnabbitTextVariant.Caption,
            fontWeight = FontWeight.SemiBold,
            color = textColor,
        )
    }
}
