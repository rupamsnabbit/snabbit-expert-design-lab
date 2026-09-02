package com.snabbit.runner.shared.core.designsystem.components

import com.snabbit.design.atoms.SnabbitImage
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.snabbit.design.theme.SnabbitColorsLight
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.resources.Res
import com.snabbit.runner.shared.resources.header_coin
import com.snabbit.runner.shared.resources.header_help
import com.snabbit.runner.shared.resources.header_saathi
import com.snabbit.runner.shared.resources.header_sos
import com.snabbit.runner.shared.resources.red_card_display
import org.jetbrains.compose.resources.DrawableResource
import org.jetbrains.compose.resources.painterResource

/**
 * One right-side header item: a foreground-only glyph inside a colored circle,
 * with a chip ([SnabbitGradientTag]) hugging its bottom edge. Built via the
 * factory helpers ([sosPill] / [saathiPill] / [coinsPill] / [helpPill]) so the
 * per-item glyph + chip styling lives in one place and both the Home and Job
 * headers stay in sync.
 */
data class HeaderNavPill(
    val glyph: DrawableResource? = null,
    val glyphBg: Color,
    val label: String,
    val chipBackground: Brush,
    val chipTextColor: Color,
    val chipBorderColor: Color? = null,
    val contentDescription: String?,
    val onClick: () -> Unit,
    /** Glyph draw size inside the 40dp circle. Portrait glyphs (the red card)
     *  pass a smaller box so their height matches the square icons visually. */
    val glyphSize: Dp = 24.dp,
    /**
     * Optional custom glyph that replaces the default gray-ringed [HeaderGlyphIcon]
     * — used by the tier badge, whose icon is a remote image in a plain white
     * circle (no hairline ring). When set, [glyph] / [glyphBg] are ignored.
     */
    val glyphContent: (@Composable () -> Unit)? = null,
)

/**
 * Reusable custom top nav: an optional [leading] slot (e.g. Home's bell) and a
 * right-aligned row of [trailing] pills. Home passes the bell + SOS/Saathi/coins;
 * the Job screen passes just Help + SOS (no leading). Stays app-local (in
 * `core/designsystem`) because no DS organism fits this stacked icon+chip layout.
 *
 * With a [leading] the row is `SpaceBetween` (leading left, pills right); without
 * one the pills sit flush right (Figma `justify-end`), matching the Job header.
 */
@Composable
fun SnabbitHeaderNav(
    trailing: List<HeaderNavPill>,
    modifier: Modifier = Modifier,
    leading: (@Composable () -> Unit)? = null,
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = if (leading != null) Arrangement.SpaceBetween else Arrangement.End,
        verticalAlignment = Alignment.Top,
    ) {
        leading?.invoke()
        Row(
            horizontalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.componentGapMd),
            verticalAlignment = Alignment.Top,
        ) {
            trailing.forEach { pill -> HeaderPillStack(pill) }
        }
    }
}

@Composable
private fun HeaderPillStack(pill: HeaderNavPill) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier
            .clickable(
                onClickLabel = pill.contentDescription ?: pill.label,
                role = Role.Button,
                onClick = pill.onClick,
            )
            // Guarantee a ≥48dp tap target — the glyph circle alone is only 40dp.
            .sizeIn(minWidth = 48.dp, minHeight = 48.dp),
    ) {
        val glyphContent = pill.glyphContent
        if (glyphContent != null) {
            glyphContent()
        } else {
            pill.glyph?.let { HeaderGlyphIcon(it, pill.glyphBg, pill.contentDescription, pill.glyphSize) }
        }
        // Slight overlap so the chip "hugs" the bottom of the icon, matching the Figma stack.
        Box(modifier = Modifier.offset(y = (-6).dp)) {
            SnabbitGradientTag(
                text = pill.label,
                background = pill.chipBackground,
                textColor = pill.chipTextColor,
                borderColor = pill.chipBorderColor,
            )
        }
    }
}

/**
 * Right-side header icon — foreground-only glyph PNG drawn at 24dp inside a 40dp
 * colored circle. Background color is provided in code so designers can ship
 * clean glyphs without baked-in bgs.
 */
@Composable
private fun HeaderGlyphIcon(
    glyph: DrawableResource,
    bgColor: Color,
    contentDescription: String?,
    glyphSize: Dp,
) {
    Box(
        modifier = Modifier
            .size(40.dp)
            .background(bgColor, CircleShape)
            // Figma 1491:15089 — 1.5px gray-200 hairline ring around every glyph circle.
            .border(1.5.dp, SnabbitColorsLight.gray200, CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        SnabbitImage(
            painter = painterResource(glyph),
            contentDescription = contentDescription,
            modifier = Modifier.size(glyphSize),
        )
    }
}

// ── Pill factories — the Snabbit-specific header items ────────────────────────
// Chip styling matches Figma (Shift/Job Lifecycle DS). SOS/coins use vertical
// gradients; Saathi + Help share the flat pink treatment (different glyph/item).

fun sosPill(label: String, onClick: () -> Unit): HeaderNavPill = HeaderNavPill(
    glyph = Res.drawable.header_sos,
    glyphBg = Color.White,
    label = label,
    chipBackground = Brush.verticalGradient(listOf(SnabbitColorsLight.red500, SnabbitColorsLight.red700)),
    chipTextColor = SnabbitColorsLight.whiteDefault,
    chipBorderColor = SnabbitColorsLight.pink300,
    contentDescription = label,
    onClick = onClick,
)

fun saathiPill(label: String, onClick: () -> Unit): HeaderNavPill = HeaderNavPill(
    glyph = Res.drawable.header_saathi,
    glyphBg = Color.White,
    label = label,
    chipBackground = Brush.linearGradient(listOf(SnabbitColorsLight.pink100, SnabbitColorsLight.pink100)),
    chipTextColor = SnabbitColorsLight.pink600,
    chipBorderColor = SnabbitColorsLight.pink300,
    contentDescription = label,
    onClick = onClick,
)

fun coinsPill(text: String, onClick: () -> Unit): HeaderNavPill = HeaderNavPill(
    glyph = Res.drawable.header_coin,
    glyphBg = SnabbitColorsLight.yellow50,
    label = text,
    chipBackground = Brush.verticalGradient(listOf(SnabbitColorsLight.yellow50, SnabbitColorsLight.yellow100)),
    chipTextColor = SnabbitColorsLight.yellow600,
    chipBorderColor = SnabbitColorsLight.pink300,
    contentDescription = null,
    onClick = onClick,
)

/**
 * Help — same flat-pink chip as [saathiPill] but its own headset glyph and item.
 * Added for the Job header (Figma 1:28063).
 */
fun helpPill(label: String, onClick: () -> Unit): HeaderNavPill = HeaderNavPill(
    glyph = Res.drawable.header_help,
    glyphBg = Color.White,
    label = label,
    chipBackground = Brush.linearGradient(listOf(SnabbitColorsLight.pink100, SnabbitColorsLight.pink100)),
    chipTextColor = SnabbitColorsLight.pink600,
    chipBorderColor = SnabbitColorsLight.pink300,
    contentDescription = label,
    onClick = onClick,
)

/**
 * Red card — count chip in the red family, mirroring [coinsPill]'s yellow
 * treatment (Flutter `HomeRewardsHeaderPill` red segment: bg `#FEE2E2` ==
 * red100, text `#B91C1C` == red700). Glyph is the "-50" red-card illustration
 * the emergency-logout sheet renders (`red_card_display`). The asset is
 * portrait, so it gets a 20dp box: its rendered HEIGHT then sits visually
 * level with the round 24dp coin.
 */
fun redCardPill(text: String, onClick: () -> Unit): HeaderNavPill = HeaderNavPill(
    glyph = Res.drawable.red_card_display,
    glyphBg = SnabbitColorsLight.red50,
    label = text,
    chipBackground = Brush.verticalGradient(listOf(SnabbitColorsLight.red50, SnabbitColorsLight.red100)),
    chipTextColor = SnabbitColorsLight.red700,
    chipBorderColor = SnabbitColorsLight.pink300,
    // New tappable target — give TalkBack a meaningful label ("Red cards, 3")
    // instead of the bare count the visual chip shows.
    contentDescription = "Red cards, $text",
    onClick = onClick,
    glyphSize = 20.dp,
)
