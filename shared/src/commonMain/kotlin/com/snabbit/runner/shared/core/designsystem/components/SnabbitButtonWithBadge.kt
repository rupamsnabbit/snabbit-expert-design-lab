package com.snabbit.runner.shared.core.designsystem.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.snabbit.design.atoms.SnabbitButton
import com.snabbit.design.atoms.SnabbitButtonSize
import com.snabbit.design.atoms.SnabbitButtonStyle
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.theme.SnabbitColorsLight

/**
 * `SnabbitButton` with an inline **badge** (e.g. a coin / red-card gamification
 * chip) rendered after the label — the KMP equivalent of Dart's gamified CTA
 * buttons ("Logout [🔴1]", "Accept job [🪙10]", Figma 220:38552 / 7114:113392).
 *
 * DS gap: `SnabbitButton` (design-system 0.16.0) exposes `text: String` with no
 * content slot, and its only composable slots — `leadingIcon` / `trailingIcon` —
 * are each wrapped in `Box(Modifier.size(tokens.iconSize))`, a hard square (24dp
 * at [SnabbitButtonSize.L]). A gamification pill is ~55dp wide, so routing it
 * through `trailingIcon` (what this shim used to do) measured it at 24dp: the
 * 16dp icon plus its 4dp gap consumed the slot and **the count silently
 * disappeared**, leaving a 24×24 rounded stub.
 *
 * So the badge cannot go through a DS slot at all. Instead the DS button renders
 * as the *surface* (background, radius, height, ripple, disabled/loading states)
 * with an empty label, and the real content — label + badge — is overlaid in a
 * centred [Row]. The overlay declares no pointer input, so taps fall through to
 * the button beneath it.
 *
 * Costs of the workaround, all deliberate and confined to this file:
 *  - the badged path is **always full-width**: the surface carries no label to
 *    size itself from, so it takes its width from the parent (every caller
 *    passes `Modifier.weight(1f)` or `fillMaxWidth`).
 *  - the label's typography is re-specified here (16sp/SemiBold — the DS `L` and
 *    `M` token value) and its colour comes from [contentColor], because the DS
 *    keeps `resolveColors` private. The default suits the filled, coloured styles
 *    these CTAs use (Destructive red-600 / Success green-600, both white-on-fill).
 *  - [enabled] deliberately does **not** dim the overlay. The DS's own
 *    `disabledColors` lightens only the *background* for Primary / Destructive /
 *    Success (e.g. Destructive red-600 → red-300) and keeps its content pure
 *    `Color.White`, so a full-strength label is what a disabled DS button of these
 *    styles already looks like. Dimming here would make the badged button the odd
 *    one out. Note this holds for the filled styles only — a caller passing a style
 *    whose disabled content *is* muted (NeutralStroke, Tertiary, …) would need to
 *    pass a matching [contentColor].
 *  - while [loading] the overlay is dropped entirely so the DS spinner is visible.
 *
 * When the DS ships a real `badge` / content slot, delete all of this and inline
 * `SnabbitButton(badge = …)` at the call sites.
 *
 * The [modifier] (often `Modifier.weight(1f)` from a RowScope caller) sits on the
 * outer [Box] so weight resolves in the parent's layout.
 */
@Composable
fun SnabbitButtonWithBadge(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    style: SnabbitButtonStyle = SnabbitButtonStyle.Primary,
    size: SnabbitButtonSize = SnabbitButtonSize.M,
    enabled: Boolean = true,
    loading: Boolean = false,
    fullWidth: Boolean = false,
    /** Label colour for the badged path — see the KDoc note on `resolveColors`. */
    contentColor: Color = SnabbitColorsLight.whiteDefault,
    badge: (@Composable () -> Unit)? = null,
) {
    // No badge (or nothing to show over): the DS button handles everything, so
    // stay entirely out of its way — same rendering as a plain SnabbitButton.
    if (badge == null || loading) {
        Box(modifier = modifier, contentAlignment = Alignment.Center) {
            SnabbitButton(
                text = text,
                onClick = onClick,
                style = style,
                size = size,
                enabled = enabled,
                loading = loading,
                fullWidth = fullWidth,
            )
        }
        return
    }

    Box(
        // The clickable node is the DS button, and on this path its label is empty, so
        // on its own it announces as an unnamed button while the real label sits in a
        // sibling. Merging the subtree and naming it here restores "<text>, button".
        modifier = modifier.semantics(mergeDescendants = true) { contentDescription = text },
        contentAlignment = Alignment.Center,
    ) {
        // Surface only — an empty label, so nothing of the DS button's own text
        // renders behind the overlay. fullWidth is forced: with no label there is
        // no intrinsic width to fall back on.
        SnabbitButton(
            text = "",
            onClick = onClick,
            style = style,
            size = size,
            enabled = enabled,
            fullWidth = true,
        )
        // The real content. No clickable/pointerInput here — taps pass through to
        // the button above. 8dp gap mirrors the DS `tokens.gap` for L/M.
        Row(
            horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            SnabbitText(
                text = text,
                color = contentColor,
                fontSize = 16.sp,
                fontWeight = FontWeight.SemiBold,
            )
            badge()
        }
    }
}
