package com.snabbit.runner.shared.features.home.presentation.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.unit.dp
import com.snabbit.design.theme.SnabbitColorsLight
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.features.home.domain.model.HomeBg

/**
 * The hero region — the bg-painted, rounded-bottom area that holds the top nav
 * and any hero-positioned cards. Picks its paint from [bg].
 *
 * Only [HomeBg.Pink] is implemented in this slice. The other arms have TODO
 * comments so the next phase that introduces them (OnLeave → Grey,
 * SearchingForJobs → Map) lands as a focused PR rather than a wholesale rewrite.
 *
 * For `Map`, the background isn't actually painted here — the map composable
 * lives as a sibling layer behind the scroll, so this arm collapses the hero
 * to nothing and the screen renders the top nav over the map directly.
 */
@Composable
fun HeroSection(
    bg: HomeBg,
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit,
) {
    when (bg) {
        HomeBg.Pink -> PinkHero(modifier, content)
        HomeBg.Grey -> {
            // TODO(home/OnLeave): grey hero — same shape as Pink with bgSecondary.
            PinkHero(modifier, content) // ponytail: placeholder until OnLeave lands
        }
        HomeBg.Map -> {
            // TODO(home/SearchingForJobs): map archetype — hero collapses; map is a
            // sibling layer behind the scroll, top nav floats over it.
            Column(modifier = modifier.fillMaxWidth(), content = content)
        }
    }
}

// Figma 2201:58597 renders the hero as a flat pink-200 fill with two large,
// heavily-blurred pink-500/400 glow circles stacked at the top. We paint the
// *rendered result* instead: a top-weighted fade from the deep glow pinks
// (pink-500 → pink-400) down to the pink-200 base — all existing DS primitives,
// matching the pink-300 border reach-in below.
@Composable
private fun PinkHero(
    modifier: Modifier,
    content: @Composable ColumnScope.() -> Unit,
) {
    val shape = RoundedCornerShape(
        bottomStart = SnabbitTheme.borderRadius.xxl,
        bottomEnd = SnabbitTheme.borderRadius.xxl,
    )
    val spacing = SnabbitTheme.spacing
    val gradient = Brush.verticalGradient(
        0f to SnabbitColorsLight.pink500,
        0.30f to SnabbitColorsLight.pink400,
        0.75f to SnabbitColorsLight.pink200,
        // ponytail: stops approximate the two top-stacked glows fading to the
        // pink-200 base; tune on device if the hot band reads too tall/short.
    )
    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(shape)
            .background(gradient, shape)
            .border(SnabbitTheme.borderWidth.thick, SnabbitColorsLight.pink300, shape)
            // Pink bleeds up behind the transparent status bar (background is applied
            // above this inset). Content clears the status bar via the real inset —
            // NOT a hardcoded guess — then sits 120dp down: the pinned top nav (~56)
            // + its 20dp top gap + the 40dp Figma gap to the first card (30:66343).
            .windowInsetsPadding(WindowInsets.statusBars)
            .padding(top = 120.dp, bottom = spacing.`6`, start = spacing.`6`, end = spacing.`6`),
        // 20dp between the attendance card and the nav card (Figma 38:26247 → 38:26524).
        verticalArrangement = Arrangement.spacedBy(spacing.`6`, Alignment.Top),
        horizontalAlignment = Alignment.CenterHorizontally,
        content = content,
    )
}
