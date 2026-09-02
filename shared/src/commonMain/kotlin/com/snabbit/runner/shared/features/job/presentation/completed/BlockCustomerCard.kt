package com.snabbit.runner.shared.features.job.presentation.completed

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.jetbrains.compose.ui.tooling.preview.Preview
import com.snabbit.design.atoms.SnabbitButton
import com.snabbit.design.atoms.SnabbitButtonSize
import com.snabbit.design.atoms.SnabbitButtonStyle
import com.snabbit.design.atoms.SnabbitCard
import com.snabbit.design.atoms.SnabbitCardLayout
import com.snabbit.design.atoms.SnabbitCardPadding
import com.snabbit.design.atoms.SnabbitCardVariant
import com.snabbit.design.atoms.SnabbitIcon
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.theme.SnabbitColorsLight
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.ui.icons.AppIcons

/**
 * **Block customer?** card — a heading + description above a bordered card that names the customer
 * and offers a destructive action. It has two states, driven by [isBlocked]:
 *
 *  - **Not blocked** (default) — a flat white [SnabbitCard] with a **Block** CTA → [onBlock].
 *    Figma "Shift — Job Lifecycle DS" node 13:9921.
 *  - **Blocked** — once the block succeeds the card flips to a **red-200 → white** horizontal
 *    gradient with an **Unblock** CTA → [onUnblock]. Figma node 13:11615. The heading copy is
 *    unchanged between the two states.
 *
 * Composes DS atoms: [SnabbitText], [SnabbitIcon] (the [AppIcons.Customer] mark), [SnabbitCard]
 * (Base, Row layout — the un-blocked container) and a Destructive [SnabbitButton] carrying the
 * [AppIcons.Block] ban glyph.
 *
 * DS-normalisation notes (Figma → DS):
 *  - The CTA maps to `SnabbitButton` size `S` (40dp, r-8) — the DS has no 36dp/r-12 size.
 *  - The blocked card's red-200 → white gradient has no `SnabbitCard` variant (Base is a flat white
 *    fill), so that container is hand-rolled — same idiom as `SnabbitRedCardNudge` — over the palette
 *    shade [SnabbitColorsLight.red200] with a [SnabbitTheme.colors.borderDefault] gray-200 border.
 *    The un-blocked `SnabbitCard(Base)` border is gray-100 1.5dp where Figma shows gray-200 1dp
 *    (kept for consistency with the sibling cards).
 *
 * @param customerName the customer being blocked (e.g. "Radhika S"), server-driven.
 * @param onBlock fired when the **Block** button is pressed (un-blocked state).
 * @param isBlocked whether the customer is already blocked — flips the card to the Unblock state.
 * @param onUnblock fired when the **Unblock** button is pressed (blocked state).
 * @param title heading copy. @param description supporting copy.
 * @param blockLabel / @param unblockLabel CTA copy for each state.
 */
@Composable
fun BlockCustomerCard(
    customerName: String,
    onBlock: () -> Unit,
    modifier: Modifier = Modifier,
    isBlocked: Boolean = false,
    onUnblock: () -> Unit = {},
    /** True while an unblock call is in flight — disables the Unblock CTA + shows its spinner (ECPO #9). */
    unblocking: Boolean = false,
    title: String = "Block Customer?",
    description: String = "Blocked customer won’t be able to book you in future.",
    blockLabel: String = "Block",
    unblockLabel: String = "Unblock",
) {
    Column(
        modifier = modifier.fillMaxWidth(),
        // Figma: 16 between the heading block and the card.
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        // ── Heading + description (stacked, no gap per Figma; identical in both states) ──
        Column {
            SnabbitText(
                text = title,
                // Body-M/16-Semibold, gray-900.
                fontSize = 16.sp,
                lineHeight = 24.sp,
                fontWeight = FontWeight.SemiBold,
                color = SnabbitTheme.colors.textPrimary,
            )
            SnabbitText(
                text = description,
                // Caption/12-Regular, gray-700.
                fontSize = 12.sp,
                lineHeight = 16.sp,
                fontWeight = FontWeight.Normal,
                color = SnabbitTheme.colors.textBody,
            )
        }

        // ── Customer name ⟶ Block / Unblock CTA ──
        if (isBlocked) {
            // Blocked: red-200 → white horizontal-gradient card. No DS gradient variant exists
            // (SnabbitCard(Base) is a flat white fill), so hand-roll it to match Figma 13:11615 —
            // the same approach SnabbitRedCardNudge uses for its gradient pill.
            val cardShape = RoundedCornerShape(12.dp)
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(cardShape)
                    .background(
                        Brush.horizontalGradient(
                            listOf(SnabbitColorsLight.red200, SnabbitTheme.colors.bgPrimary),
                        ),
                    )
                    .border(1.dp, SnabbitTheme.colors.borderDefault, cardShape)
                    .padding(12.dp),
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    CustomerNameRow(customerName)
                    BlockActionButton(label = unblockLabel, onClick = onUnblock, enabled = !unblocking, loading = unblocking)
                }
            }
        } else {
            // Not blocked: flat white card, Block CTA. SnabbitCard(Row) spaces the two children apart.
            SnabbitCard(
                modifier = Modifier.fillMaxWidth(),
                variant = SnabbitCardVariant.Base,
                padding = SnabbitCardPadding.Md,
                layout = SnabbitCardLayout.Row,
            ) {
                CustomerNameRow(customerName)
                BlockActionButton(label = blockLabel, onClick = onBlock)
            }
        }
    }
}

/** Customer mark + name — the left side of the card row, shared by both states. */
@Composable
private fun CustomerNameRow(customerName: String) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        SnabbitIcon(
            imageVector = AppIcons.Customer,
            size = 16.dp,
            color = SnabbitTheme.colors.textPrimary,
        )
        SnabbitText(
            text = customerName,
            // Body-M/16-Semibold, gray-900.
            fontSize = 16.sp,
            lineHeight = 24.sp,
            fontWeight = FontWeight.SemiBold,
            color = SnabbitTheme.colors.textPrimary,
        )
    }
}

/** Destructive CTA carrying the ban glyph — labelled "Block" or "Unblock" per state. */
@Composable
private fun BlockActionButton(
    label: String,
    onClick: () -> Unit,
    enabled: Boolean = true,
    loading: Boolean = false,
) {
    SnabbitButton(
        text = label,
        onClick = onClick,
        style = SnabbitButtonStyle.Destructive,
        size = SnabbitButtonSize.S,
        enabled = enabled,
        loading = loading,
        leadingIcon = {
            // Multi-part (faint disc + ring + slash), so render via foundation Image —
            // a single-tint SnabbitIcon would flatten the 20%-alpha disc.
            Image(
                imageVector = AppIcons.Block,
                contentDescription = null,
                modifier = Modifier.size(18.dp),
            )
        },
    )
}

/* ── Preview ─────────────────────────────────────────────────────────── */

@Preview
@Composable
private fun PreviewBlockCustomerCard() {
    SnabbitTheme {
        Column(
            modifier = Modifier.background(SnabbitTheme.colors.bgSecondary).padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(24.dp),
        ) {
            BlockCustomerCard(customerName = "Radhika S", onBlock = {})
            BlockCustomerCard(
                customerName = "Radhika S",
                onBlock = {},
                isBlocked = true,
                onUnblock = {},
            )
        }
    }
}
