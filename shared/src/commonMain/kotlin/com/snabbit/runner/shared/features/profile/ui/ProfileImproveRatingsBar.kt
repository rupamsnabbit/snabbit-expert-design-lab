package com.snabbit.runner.shared.features.profile.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.atoms.SnabbitTextVariant

/**
 * The "Improve Ratings" call-to-action bar (drawer parity — `expert_info`): a
 * full-width tappable bar with a star chip + "Improve Ratings" + chevron, opening
 * the Flutter Performance page. Shown only when the runner has a rating (the rating
 * value itself stays hidden per product decision).
 *
 * Two colour variants mirror the drawer: a calm light-gray/gold bar when the runner
 * is [highlyRated] (rating ≥ [ProfileTileDefaults.HighlyRatedThreshold]), else a red
 * "needs attention" bar. **Material 3** ([Surface] onClick ripple). `commonMain`.
 */
@Composable
fun ProfileImproveRatingsBar(
    highlyRated: Boolean,
    onClick: () -> Unit,
    label: String = "Improve Ratings",
    modifier: Modifier = Modifier,
) {
    val barColor = if (highlyRated) ProfileTileDefaults.ImproveRatingsBgHigh else ProfileTileDefaults.ImproveRatingsBg
    val starCircle = if (highlyRated) ProfileTileDefaults.ImproveRatingsStarCircleHigh else ProfileTileDefaults.ImproveRatingsStarCircle
    val contentColor = if (highlyRated) ProfileTileDefaults.ImproveRatingsTextHigh else ProfileTileDefaults.ImproveRatingsText

    Surface(
        onClick = onClick,
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(ProfileTileDefaults.ImproveRatingsRadius),
        color = barColor,
    ) {
        Row(
            modifier = Modifier.padding(
                horizontal = ProfileTileDefaults.ImproveRatingsPaddingH,
                vertical = ProfileTileDefaults.ImproveRatingsPaddingV,
            ),
            horizontalArrangement = Arrangement.spacedBy(ProfileTileDefaults.ImproveRatingsGap),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                modifier = Modifier
                    .size(ProfileTileDefaults.ImproveRatingsStarBox)
                    .clip(CircleShape)
                    .background(starCircle),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = Icons.Rounded.Star,
                    contentDescription = null,
                    tint = ProfileTileDefaults.ImproveRatingsStar,
                    modifier = Modifier.size(ProfileTileDefaults.ImproveRatingsStarIcon),
                )
            }
            SnabbitText(
                text = label,
                variant = SnabbitTextVariant.BodyMd,
                fontSize = 14.sp,
                fontWeight = FontWeight.Medium,
                color = contentColor,
                modifier = Modifier.weight(1f),
            )
            Icon(
                imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
                contentDescription = null,
                tint = contentColor,
                modifier = Modifier.size(ProfileTileDefaults.ImproveRatingsChevron),
            )
        }
    }
}
