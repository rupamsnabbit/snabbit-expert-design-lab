package com.snabbit.runner.shared.features.profile.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.atoms.SnabbitTextVariant

/**
 * Renders one [ProfileSection] — a section header + a white **Material 3** card that
 * groups the section's rows, separated by hairline [HorizontalDivider]s. Styled 1:1
 * with Figma node `933:32278` (card: white, radius 16, 20 padding, 16 gap between
 * rows/dividers, no shadow; divider: gray-100 hairline).
 *
 * Pure Material 3 (`Surface` + `HorizontalDivider` + `Text`). Rows come from data
 * ([ProfileSection.items]) and are composed **eagerly** in a `Column` — a card is a
 * bounded group and a single item of the screen's outer `LazyColumn`, which owns
 * scrolling (a nested lazy list here would get an unbounded-height constraint).
 * `commonMain` / iOS-safe.
 */
@Composable
fun ProfileSectionCard(
    section: ProfileSection,
    modifier: Modifier = Modifier,
) {
    if (section.items.isEmpty()) return
    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        SnabbitText(
            text = section.title,
            variant = SnabbitTextVariant.BodyLg,
            fontSize = 16.sp,
            fontWeight = FontWeight.SemiBold,
            color = ProfileTileDefaults.SectionTitle,
        )
        Surface(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(ProfileTileDefaults.CardCornerRadius),
            color = ProfileTileDefaults.CardBackground,
        ) {
            Column(
                // Only vertical card padding here; each row owns its horizontal + vertical
                // padding inside its clickable, so the whole tile (full width + the gap)
                // is tappable and the M3 ripple covers it. CardVerticalPadding + the row's
                // top/bottom padding = the 20 content inset; the divider is inset to match.
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = ProfileTileDefaults.CardVerticalPadding),
            ) {
                section.items.forEachIndexed { index, item ->
                    if (index > 0) {
                        HorizontalDivider(
                            modifier = Modifier.padding(horizontal = ProfileTileDefaults.DividerInset),
                            thickness = ProfileTileDefaults.DividerThickness,
                            color = ProfileTileDefaults.Divider,
                        )
                    }
                    ProfileMenuRow(
                        label = item.label,
                        leadingIcon = item.leadingIcon,
                        labelColor = item.labelColor,
                        value = item.value,
                        valueColor = item.valueColor,
                        showNewBadge = item.showNewBadge,
                        showChevron = item.showChevron,
                        onClick = item.onClick,
                    )
                }
            }
        }
    }
}
