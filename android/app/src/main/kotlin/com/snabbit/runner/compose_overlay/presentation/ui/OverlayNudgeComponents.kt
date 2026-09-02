package com.snabbit.runner.compose_overlay.presentation.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.NotificationsOff
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import coil.request.ImageRequest

// Mirrors Flutter NudgeBanner colour tokens — risk/opportunity/bonus.
private data class OverlayNudgeTheme(
    val background: Color,
    val border: Color,
    val textPrimary: Color,
    val badgeBackground: Color,
)

private fun nudgeThemeFor(nudgeKind: String): OverlayNudgeTheme = when (nudgeKind) {
    "bonus" -> OverlayNudgeTheme(
        background = Color(0xFF1D4ED8),   // blue-700
        border = Color(0xFF93C5FD),        // blue-300
        textPrimary = Color.White,
        badgeBackground = Color(0xFF3B82F6), // blue-500
    )
    "opportunity" -> OverlayNudgeTheme(
        background = Color(0xFFFFFBEB),   // yellow-50
        border = Color(0xFFFDE68A),        // yellow-200
        textPrimary = Color(0xFFD97706),   // amber-600
        badgeBackground = Color(0xFFFEF3C7), // yellow-100
    )
    else -> OverlayNudgeTheme(             // "risk" and unknown → red theme
        background = Color(0xFFFEF2F2),   // red-50
        border = Color(0xFFFCA5A5),        // red-300
        textPrimary = Color(0xFFDC2626),   // red-600
        badgeBackground = Color(0xFFFEE2E2), // red-100
    )
}

/**
 * Generic pre-action nudge strip for the AWOL breach overlay.
 *
 * Non-compact (dialog): notification icon + "Outside Hotspot" context label + icon/count badge.
 * Compact (mini overlay): nudge icon + [labelText] (resolved server string with params applied).
 *
 * Colours are driven by [nudgeKind] to match Flutter's NudgeBanner theming:
 *   "risk" → red, "opportunity" → yellow, "bonus" → blue.
 */
@Composable
fun RedCardPenaltyNudge(
    redCardCount: Int,
    iconUrl: String,
    nudgeKind: String = "risk",
    labelText: String? = null,
    compact: Boolean = false,
    outsideHotspotLabel: String = "Outside Hotspot",
    modifier: Modifier = Modifier,
) {
    val theme = nudgeThemeFor(nudgeKind)
    val cornerRadius: Dp = if (compact) 6.dp else 8.dp
    val horizontalPad: Dp = if (compact) 8.dp else 12.dp
    val verticalPad: Dp = if (compact) 4.dp else 8.dp

    Surface(
        modifier = modifier
            .fillMaxWidth()
            .border(width = 1.dp, color = theme.border, shape = RoundedCornerShape(cornerRadius)),
        shape = RoundedCornerShape(cornerRadius),
        color = theme.background,
    ) {
        if (compact) {
            // Mini overlay: nudge icon + server-resolved label text (e.g. "+2 red cards will be added").
            // If labelText is absent the icon alone still signals the penalty.
            Row(
                modifier = Modifier.padding(horizontal = horizontalPad, vertical = verticalPad),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                AsyncImage(
                    model = ImageRequest.Builder(LocalContext.current)
                        .data(iconUrl)
                        .allowHardware(false)
                        .build(),
                    contentDescription = null,
                    modifier = Modifier.size(12.dp),
                )
                val resolvedLabel = labelText?.takeIf { it.isNotBlank() }
                if (resolvedLabel != null) {
                    Text(
                        text = resolvedLabel,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        fontFamily = MetropolisFamily,
                        color = theme.textPrimary,
                        lineHeight = 16.sp,
                    )
                }
            }
        } else {
            // Dialog: [notification icon] ["Outside Hotspot" context label] [icon + count badge]
            Row(
                modifier = Modifier.padding(horizontal = horizontalPad, vertical = verticalPad),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(
                    imageVector = Icons.Default.NotificationsOff,
                    contentDescription = null,
                    tint = theme.textPrimary,
                    modifier = Modifier.size(20.dp),
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = outsideHotspotLabel,
                    fontSize = 13.sp,
                    fontWeight = FontWeight.SemiBold,
                    fontFamily = MetropolisFamily,
                    color = theme.textPrimary,
                    modifier = Modifier.weight(1f),
                    lineHeight = 18.sp,
                )
                Row(
                    modifier = Modifier
                        .background(theme.badgeBackground, RoundedCornerShape(20.dp))
                        .padding(horizontal = 8.dp, vertical = 3.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    AsyncImage(
                        model = ImageRequest.Builder(LocalContext.current)
                            .data(iconUrl)
                            .allowHardware(false)
                            .build(),
                        contentDescription = null,
                        modifier = Modifier.size(12.dp),
                    )
                    Text(
                        text = "$redCardCount",
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Bold,
                        fontFamily = MetropolisFamily,
                        color = theme.textPrimary,
                        lineHeight = 16.sp,
                    )
                }
            }
        }
    }
}
