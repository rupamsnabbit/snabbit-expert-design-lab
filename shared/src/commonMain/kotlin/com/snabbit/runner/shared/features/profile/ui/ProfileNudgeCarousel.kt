package com.snabbit.runner.shared.features.profile.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import org.jetbrains.compose.resources.DrawableResource

/** A profile nudge: prompt text + an optional action (e.g. "Add") + optional icon SVG. */
data class ProfileNudge(
    val text: String,
    val actionLabel: String? = null,
    /** Stable nudge type for analytics: bank / aadhaar_rekyc / pan / pan_aadhaar.
     *  Required — a new nudge must declare its analytics id (no silent empty). */
    val type: String,
    val icon: DrawableResource? = null,
    val onAction: (() -> Unit)? = null,
)

/**
 * The top nudge strip: one full-width card for a single nudge, else a swipeable
 * [HorizontalPager] with dot indicators (Figma 933:32268 / 933:32935).
 *
 * Cards are **flush-left** with a small **right peek** (`contentPadding(end = NudgePeek)`)
 * showing the next card's leading edge (icon-first), clipped square at the edge with the
 * card's own rounded corners — matching Figma. The pager is **circular** (huge virtual page
 * count mapped back via `%`) so the last card's "next" wraps to the first — the peek is
 * always filled, no empty trailing edge. All cards share a fixed height ([ProfileNudgeCard])
 * → no flicker; dots are all the **same size** (active differs by colour only).
 * `commonMain` / iOS-safe.
 */
@Composable
fun ProfileNudgeCarousel(
    nudges: List<ProfileNudge>,
    modifier: Modifier = Modifier,
) {
    if (nudges.isEmpty()) return

    if (nudges.size == 1) {
        val nudge = nudges.first()
        ProfileNudgeCard(
            text = nudge.text,
            leadingIcon = nudge.icon,
            actionLabel = nudge.actionLabel,
            onAction = nudge.onAction,
            modifier = modifier.fillMaxWidth(),
        )
        return
    }

    val pageCount = nudges.size
    // Circular: a huge virtual page count, started near the middle on a real-index boundary,
    // so the user can swipe both ways forever and every page has neighbours to peek.
    val startPage = (Int.MAX_VALUE / 2).let { it - it % pageCount }
    val pagerState = rememberPagerState(initialPage = startPage, pageCount = { Int.MAX_VALUE })
    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(ProfileTileDefaults.DotsTopGap),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        HorizontalPager(
            state = pagerState,
            contentPadding = PaddingValues(end = ProfileTileDefaults.NudgePeek),
            pageSpacing = ProfileTileDefaults.NudgePageSpacing,
            modifier = Modifier.fillMaxWidth(),
        ) { page ->
            val nudge = nudges[page % pageCount]
            ProfileNudgeCard(
                text = nudge.text,
                leadingIcon = nudge.icon,
                actionLabel = nudge.actionLabel,
                onAction = nudge.onAction,
                modifier = Modifier.fillMaxWidth(),
            )
        }
        Row(horizontalArrangement = Arrangement.spacedBy(ProfileTileDefaults.DotGap)) {
            val activeIndex = pagerState.currentPage % pageCount
            repeat(pageCount) { index ->
                Box(
                    modifier = Modifier
                        .size(ProfileTileDefaults.DotSize) // same size for all — active differs by colour only
                        .clip(CircleShape)
                        .background(
                            if (index == activeIndex) ProfileTileDefaults.DotActive
                            else ProfileTileDefaults.DotInactive,
                        ),
                )
            }
        }
    }
}
