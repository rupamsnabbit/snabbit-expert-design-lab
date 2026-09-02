package com.snabbit.runner.shared.features.profile.ui

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.outlined.BrokenImage
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.sp
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.atoms.SnabbitTextVariant
import org.jetbrains.compose.resources.DrawableResource
import org.jetbrains.compose.resources.painterResource

/**
 * A single tappable menu row for the Profile screen — **Material 3**, styled 1:1 with
 * Figma node `933:32278`.
 *
 * The **whole tile is clickable**: the row is wrapped in an M3 `Surface(onClick = …)`
 * (M3 ripple + state layers), and [contentPadding] lives *inside* it — so the ripple
 * spans the **full card width** and the vertical gap between rows (a comfortable tap
 * target), while the content stays inset per Figma. The outer [ProfileSectionCard]
 * `Surface` clips the top/bottom rows' ripple to the card's rounded corners.
 *
 * Content layout: `[icon 20] —12— label …(flex)… value —8— NEW —8— chevron 16`,
 * vertically centred. The leading group is the only flexible element (`weight(1f)`),
 * so a long/translated label **ellipsizes at 2 lines** instead of pushing the trailing
 * value/chevron off-screen. `commonMain` / iOS-safe (Material 3 + material-icons +
 * foundation layout only).
 *
 * @param leadingIcon per-tile SVG drawable, rendered **untinted** ([Image]) so its baked
 *   colours show as designed; a **"missing image" placeholder** ([Icons.Outlined.BrokenImage])
 *   is shown when null, making it obvious which tiles still need an SVG.
 * @param value optional trailing text (e.g. an amount) — Semibold, green by default.
 * @param showNewBadge shows the pink "NEW" pill before the chevron.
 * @param showChevron trailing ›; auto-mirrors in RTL.
 */
@Composable
fun ProfileMenuRow(
    label: String,
    modifier: Modifier = Modifier,
    contentPadding: PaddingValues = PaddingValues(
        horizontal = ProfileTileDefaults.RowPaddingH,
        vertical = ProfileTileDefaults.RowPaddingV,
    ),
    leadingIcon: DrawableResource? = null,
    labelColor: Color = ProfileTileDefaults.Label,
    value: String? = null,
    valueColor: Color = ProfileTileDefaults.Value,
    showNewBadge: Boolean = false,
    showChevron: Boolean = true,
    onClick: (() -> Unit)? = null,
) {
    if (onClick != null) {
        Surface(
            onClick = onClick,
            modifier = modifier.fillMaxWidth(),
            color = Color.Transparent, // no fill over the card; onClick still gives the M3 ripple
        ) {
            ProfileMenuRowContent(
                contentPadding, leadingIcon, label, labelColor,
                value, valueColor, showNewBadge, showChevron,
            )
        }
    } else {
        ProfileMenuRowContent(
            contentPadding, leadingIcon, label, labelColor,
            value, valueColor, showNewBadge, showChevron,
            modifier = modifier,
        )
    }
}

@Composable
private fun ProfileMenuRowContent(
    contentPadding: PaddingValues,
    leadingIcon: DrawableResource?,
    label: String,
    labelColor: Color,
    value: String?,
    valueColor: Color,
    showNewBadge: Boolean,
    showChevron: Boolean,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier.fillMaxWidth().padding(contentPadding),
        horizontalArrangement = Arrangement.spacedBy(ProfileTileDefaults.TrailingGap),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        // Leading group — the ONLY flexible element; it yields first so the label
        // ellipsizes rather than shoving the value/chevron out.
        Row(
            modifier = Modifier.weight(1f),
            horizontalArrangement = Arrangement.spacedBy(ProfileTileDefaults.LeadingGap),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            if (leadingIcon != null) {
                // Real per-tile SVG — untinted so its baked (duotone) colours render as designed.
                Image(
                    painter = painterResource(leadingIcon),
                    contentDescription = null,
                    modifier = Modifier.size(ProfileTileDefaults.LeadingIconSize),
                )
            } else {
                // No SVG yet for this tile → obvious "missing image" placeholder (TODO(icons)).
                Icon(
                    imageVector = Icons.Outlined.BrokenImage,
                    contentDescription = null,
                    tint = ProfileTileDefaults.LeadingIcon,
                    modifier = Modifier.size(ProfileTileDefaults.LeadingIconSize),
                )
            }
            SnabbitText(
                text = label,
                variant = SnabbitTextVariant.BodyLg,
                fontSize = 16.sp,
                fontWeight = FontWeight.Medium,
                color = labelColor,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f),
            )
        }
        // Trailing group — intrinsic width, kept intact.
        Row(
            horizontalArrangement = Arrangement.spacedBy(ProfileTileDefaults.TrailingGap),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            if (value != null) {
                SnabbitText(
                    text = value,
                    variant = SnabbitTextVariant.BodyLg,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = valueColor,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            if (showNewBadge) {
                NewBadge()
            }
            if (showChevron) {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
                    contentDescription = null,
                    tint = ProfileTileDefaults.Chevron,
                    modifier = Modifier.size(ProfileTileDefaults.ChevronSize),
                )
            }
        }
    }
}

/** The pink "NEW" pill (Figma Tags / soft-brand). */
@Composable
private fun NewBadge() {
    Surface(
        color = ProfileTileDefaults.BadgeBackground,
        shape = RoundedCornerShape(ProfileTileDefaults.BadgeCornerRadius),
    ) {
        SnabbitText(
            text = "NEW",
            variant = SnabbitTextVariant.Caption,
            fontSize = 12.sp,
            fontWeight = FontWeight.Medium,
            color = ProfileTileDefaults.BadgeText,
            maxLines = 1,
            modifier = Modifier.padding(
                horizontal = ProfileTileDefaults.BadgePaddingH,
                vertical = ProfileTileDefaults.BadgePaddingV,
            ),
        )
    }
}
