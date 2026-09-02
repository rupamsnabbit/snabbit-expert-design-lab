package com.snabbit.runner.shared.features.profile.ui

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.BrokenImage
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.sp
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.atoms.SnabbitTextVariant
import org.jetbrains.compose.resources.DrawableResource
import org.jetbrains.compose.resources.painterResource

/**
 * A single "info + optional action" nudge card — **Material 3**, styled 1:1 with Figma
 * node `933:32268`: pink-50 fill, 1.5dp pink-100 border, radius 12, padding 16, a
 * leading icon + prompt text, and an optional trailing "Add" button.
 *
 * **Fixed height** ([ProfileTileDefaults.NudgeCardHeight]) so every card in the
 * [ProfileNudgeCarousel] is the same height — a card without a button (or with 2-line
 * text) doesn't shrink/grow between pages (no flicker). `commonMain` / iOS-safe.
 *
 * @param leadingIcon per-nudge SVG drawable, rendered **untinted** ([Image]); a "missing
 *   image" placeholder ([Icons.Outlined.BrokenImage]) is shown when null (TODO(icons)).
 */
@Composable
fun ProfileNudgeCard(
    text: String,
    modifier: Modifier = Modifier,
    leadingIcon: DrawableResource? = null,
    actionLabel: String? = null,
    onAction: (() -> Unit)? = null,
) {
    Row(
        // Width is caller-controlled: `fillMaxWidth()` for a lone card; a fixed
        // `requiredWidth()` inside the carousel so a masked peek reveals the card's
        // start (icon) rather than its centre.
        modifier = modifier
            .height(ProfileTileDefaults.NudgeCardHeight)
            .clip(RoundedCornerShape(ProfileTileDefaults.NudgeCardRadius))
            .background(ProfileTileDefaults.NudgeBackground)
            .border(
                width = ProfileTileDefaults.NudgeBorderWidth,
                color = ProfileTileDefaults.NudgeBorder,
                shape = RoundedCornerShape(ProfileTileDefaults.NudgeCardRadius),
            )
            .padding(ProfileTileDefaults.NudgePadding),
        horizontalArrangement = Arrangement.spacedBy(ProfileTileDefaults.NudgeContentGap),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (leadingIcon != null) {
            // Real per-nudge SVG — untinted so its baked colours render as designed.
            Image(
                painter = painterResource(leadingIcon),
                contentDescription = null,
                modifier = Modifier.size(ProfileTileDefaults.NudgeIconSize),
            )
        } else {
            // No SVG yet for this nudge → obvious "missing image" placeholder (TODO(icons)).
            Icon(
                imageVector = Icons.Outlined.BrokenImage,
                contentDescription = null,
                tint = ProfileTileDefaults.NudgeIcon,
                modifier = Modifier.size(ProfileTileDefaults.NudgeIconSize),
            )
        }
        SnabbitText(
            text = text,
            variant = SnabbitTextVariant.BodyMd,
            fontSize = 14.sp,
            fontWeight = FontWeight.SemiBold,
            color = ProfileTileDefaults.NudgeText,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f),
        )
        if (actionLabel != null && onAction != null) {
            NudgeActionButton(label = actionLabel, onClick = onAction)
        }
    }
}

/** The pink "Add" pill button (Figma Buttons — pink-600, h36, radius 8). */
@Composable
private fun NudgeActionButton(label: String, onClick: () -> Unit) {
    Surface(
        onClick = onClick,
        shape = RoundedCornerShape(ProfileTileDefaults.NudgeButtonRadius),
        color = ProfileTileDefaults.NudgeButton,
    ) {
        Box(
            modifier = Modifier
                .height(ProfileTileDefaults.NudgeButtonHeight)
                .padding(horizontal = ProfileTileDefaults.NudgeButtonPaddingH),
            contentAlignment = Alignment.Center,
        ) {
            SnabbitText(
                text = label,
                variant = SnabbitTextVariant.BodyMd,
                fontSize = 14.sp,
                fontWeight = FontWeight.Medium,
                color = ProfileTileDefaults.NudgeButtonText,
                maxLines = 1,
            )
        }
    }
}
