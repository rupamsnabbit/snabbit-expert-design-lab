package com.snabbit.runner.shared.core.designsystem.components

import com.snabbit.design.atoms.SnabbitImage
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.atoms.SnabbitTextVariant
import com.snabbit.design.theme.SnabbitTheme
import org.jetbrains.compose.resources.DrawableResource
import org.jetbrains.compose.resources.painterResource

data class SnabbitTabSpec(
    val activeIcon: DrawableResource,
    val inactiveIcon: DrawableResource,
    val label: String,
    val badgeText: String? = null, // seam only; ribbon not rendered yet
)

/**
 * App bottom navigation, built on Material 3's [NavigationBar] / [NavigationBarItem]
 * (the DS layer is the sanctioned home for material3 chrome), themed with Snabbit
 * tokens rather than the stock M3 palette:
 *  - container = `bgPrimary`, with a hairline top divider for separation on white
 *    (the app doesn't lean on M3's tonal-elevation separation),
 *  - selected active-indicator pill = `bgBrandSubtle` (the light-pink capsule behind
 *    the icon — M3's own behind-icon indicator),
 *  - a `bgBrand` top-line indicator hanging from the bar's top edge over the selected
 *    tab (Figma 971:54136 — M3 has no top-line slot, so it's overlaid),
 *  - label = `textBrand` when selected, `textTertiary` otherwise.
 *
 * Icons are pre-coloured active/inactive drawables (swapped on selection), so they
 * render as-is — the M3 icon tint is left at its default and doesn't apply to an
 * [Image].
 */
@Composable
fun SnabbitBottomTabBar(
    tabs: List<SnabbitTabSpec>,
    selectedIndex: Int,
    onSelect: (Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier.fillMaxWidth()) {
        HorizontalDivider(thickness = 1.dp, color = SnabbitTheme.colors.borderDefault)
        Box {
            NavigationBar(
                containerColor = SnabbitTheme.colors.bgPrimary,
                tonalElevation = 0.dp,
            ) {
                tabs.forEachIndexed { index, spec ->
                    val selected = index == selectedIndex
                    NavigationBarItem(
                        selected = selected,
                        onClick = { onSelect(index) },
                        icon = {
                            SnabbitImage(
                                painter = painterResource(if (selected) spec.activeIcon else spec.inactiveIcon),
                                contentDescription = spec.label,
                                modifier = Modifier.size(24.dp),
                            )
                        },
                        label = {
                            SnabbitText(
                                text = spec.label,
                                variant = SnabbitTextVariant.Caption,
                                color = if (selected) {
                                    SnabbitTheme.colors.textBrand
                                } else {
                                    SnabbitTheme.colors.textTertiary
                                },
                                fontWeight = FontWeight.Medium,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                            )
                        },
                        alwaysShowLabel = true,
                        colors = NavigationBarItemDefaults.colors(
                            indicatorColor = SnabbitTheme.colors.bgBrandSubtle,
                            selectedTextColor = SnabbitTheme.colors.textBrand,
                            unselectedTextColor = SnabbitTheme.colors.textTertiary,
                        ),
                    )
                }
            }
            // Top-line indicator overlay. NavigationBar lays its items out edge-to-edge
            // with equal weight, so a matching row of equal-weight cells centres each
            // line over its tab. Only the selected tab's line is drawn; the row is only
            // as tall as the 2.dp line and doesn't intercept taps.
            Row(modifier = Modifier.fillMaxWidth().align(Alignment.TopStart)) {
                tabs.forEachIndexed { index, _ ->
                    Box(modifier = Modifier.weight(1f), contentAlignment = Alignment.TopCenter) {
                        if (index == selectedIndex) {
                            Box(
                                modifier = Modifier
                                    .width(48.dp)
                                    .height(2.dp)
                                    .background(
                                        SnabbitTheme.colors.bgBrand,
                                        RoundedCornerShape(
                                            bottomStart = SnabbitTheme.borderRadius.full,
                                            bottomEnd = SnabbitTheme.borderRadius.full,
                                        ),
                                    ),
                            )
                        }
                    }
                }
            }
        }
    }
}
