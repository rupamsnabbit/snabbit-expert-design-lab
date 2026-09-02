package com.snabbit.runner.shared.features.job.presentation.inprogress

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.jetbrains.compose.ui.tooling.preview.Preview
import com.snabbit.design.atoms.SnabbitCard
import com.snabbit.design.atoms.SnabbitCardPadding
import com.snabbit.design.atoms.SnabbitCardVariant
import com.snabbit.design.atoms.SnabbitIcon
import com.snabbit.design.atoms.SnabbitListContainer
import com.snabbit.design.atoms.SnabbitListItem
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.theme.SnabbitColorsLight
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.ui.icons.AppIcons

/**
 * **Customer preferences** card — a titled card listing the customer's cooking preferences
 * (spice / oil level, …), each a `label ⟶ value` row with a leading glyph, split by hairlines.
 *
 * Figma "Shift — Job Lifecycle DS" node 6:8408. Composes DS atoms: [SnabbitCard] (the container),
 * [SnabbitListItem] (each row's leading/label + trailing value), [SnabbitText] and [SnabbitIcon].
 * Scales to any number of [items] and renders **nothing** when empty (mirroring the Flutter
 * `SizedBox.shrink()` when `cooking_preference` is absent).
 *
 * @param title section heading (e.g. "Customer preferences"), server-driven copy.
 */
@Composable
fun CustomerPreferencesCard(
    title: String,
    items: List<CustomerPreferenceItem>,
    modifier: Modifier = Modifier,
) {
    if (items.isEmpty()) return

    Column(
        modifier = modifier.fillMaxWidth(),
        // Figma: 12 between the heading and the card.
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        SnabbitText(
            text = title,
            // Body-L/18-Semibold, gray-900 (DS `bodyLg` is 16sp, so size the Figma value explicitly).
            fontSize = 18.sp,
            lineHeight = 24.sp,
            fontWeight = FontWeight.SemiBold,
            color = SnabbitTheme.colors.textPrimary,
        )

        SnabbitCard(
            modifier = Modifier.fillMaxWidth(),
            // Base = white fill, 1.5dp gray-100 border, r-12; Lg = 16dp inner padding (per Figma).
            variant = SnabbitCardVariant.Base,
            padding = SnabbitCardPadding.Lg,
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                items.forEachIndexed { index, item ->
                    if (index > 0) {
                        // gray-100 hairline. DS `SnabbitDivider(Line)` is gray-200; the Figma spec is
                        // gray-100 (matching the card border), so we draw the 1px line from the token.
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(1.dp)
                                .background(SnabbitTheme.colors.borderSubtle),
                        )
                    }
                    CustomerPreferenceRow(item)
                }
            }
        }
    }
}

/**
 * A single preference row. Uses [SnabbitListItem]'s 3-slot core so the value sits opposite the
 * label (space-between), keeping the icon↔label gap at the Figma 8dp inside the `content` slot
 * (the core's leading↔content gap is a fixed 12dp).
 */
@Composable
private fun CustomerPreferenceRow(item: CustomerPreferenceItem) {
    SnabbitListItem(
        container = SnabbitListContainer.Plain,
        titleContent = {
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                item.icon?.let { icon ->
                    SnabbitIcon(imageVector = icon, size = 16.dp, color = SnabbitColorsLight.gray600)
                }
                SnabbitText(
                    text = item.label,
                    // Body-M/16-Regular, gray-500.
                    fontSize = 16.sp,
                    lineHeight = 24.sp,
                    fontWeight = FontWeight.Normal,
                    color = SnabbitTheme.colors.textSecondary,
                )
            }
        },
        trailingContent = {
            SnabbitText(
                text = item.value,
                // Body-M/16-Semibold, gray-700.
                fontSize = 16.sp,
                lineHeight = 24.sp,
                fontWeight = FontWeight.SemiBold,
                color = SnabbitTheme.colors.textBody,
            )
        },
    )
}

/**
 * Maps a `cooking_preference` key to its row glyph. Known keys get a specific icon; unknown keys
 * return null (the row renders without a leading icon), so new preferences degrade gracefully.
 * Extend as the backend adds preferences.
 */
fun customerPreferenceIcon(prefKey: String): ImageVector? = when (prefKey.trim().lowercase()) {
    "spice_level", "spice" -> AppIcons.SpiceLevel
    "oil_level", "oil" -> AppIcons.OilLevel
    else -> null
}

/* ── Preview ─────────────────────────────────────────────────────────── */

@Preview
@Composable
private fun PreviewCustomerPreferencesCard() {
    SnabbitTheme {
        Box(Modifier.background(SnabbitTheme.colors.bgSecondary).padding(16.dp)) {
            CustomerPreferencesCard(
                title = "Customer preferences",
                items = listOf(
                    CustomerPreferenceItem("Spice level", "Low", AppIcons.SpiceLevel),
                    CustomerPreferenceItem("Oil level", "Medium", AppIcons.OilLevel),
                ),
            )
        }
    }
}
