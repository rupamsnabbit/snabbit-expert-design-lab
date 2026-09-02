package com.snabbit.runner.shared.features.home.presentation.ui

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.unit.dp
import com.snabbit.design.theme.SnabbitTheme

/**
 * First-load placeholder for the Home hero — rendered in place of `heroCards`
 * while [com.snabbit.runner.shared.features.home.presentation.HomeUiState.isLoading],
 * i.e. before `ShiftProjector` delivers its first `current_state` envelope (or
 * the load timeout fires).
 *
 * Two white card skeletons (avatar + text lines + CTA bar) approximate the
 * attendance-card stack so the layout doesn't jump when real cards replace them,
 * and a light streak sweeps across the grey bars.
 *
 * ponytail: hand-rolled shimmer — the DS (design-system 0.11.0) ships no
 * shimmer/skeleton atom (only `SnabbitProgressBar`). Built from foundation
 * primitives (an animated `Brush` over token-coloured `Box`es), which the
 * `:shared` DS rules permit for layout. Swap for a DS `SnabbitShimmer` the
 * moment one lands. [[project-home-cmp-ds-gaps]]
 */
@Composable
fun HomeHeroShimmer(modifier: Modifier = Modifier) {
    Column(
        modifier = modifier.fillMaxWidth(),
        // Same 16dp inter-card gap PinkHero uses between hero items.
        verticalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.`5`),
    ) {
        ShimmerCard(withCta = true)
        ShimmerCard(withCta = false)
    }
}

/** A white card silhouette: header row (avatar + two title lines) and, when
 *  [withCta], two body lines plus a button-height bar. */
@Composable
private fun ShimmerCard(withCta: Boolean) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(SnabbitTheme.borderRadius.xl))
            // White surface — matches the real attendance cards on the pink hero.
            .background(SnabbitTheme.colors.bgPrimary)
            .padding(SnabbitTheme.spacing.`5`),
        verticalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.`4`),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.`4`),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            ShimmerBar(Modifier.size(44.dp), shape = CircleShape)
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.`3`),
            ) {
                ShimmerBar(Modifier.fillMaxWidth(0.6f).height(14.dp))
                ShimmerBar(Modifier.fillMaxWidth(0.4f).height(12.dp))
            }
        }
        if (withCta) {
            ShimmerBar(Modifier.fillMaxWidth().height(12.dp))
            ShimmerBar(Modifier.fillMaxWidth(0.85f).height(12.dp))
            ShimmerBar(
                Modifier.fillMaxWidth().height(44.dp),
                shape = RoundedCornerShape(SnabbitTheme.borderRadius.lg),
            )
        }
    }
}

/** A single grey placeholder bar carrying the sweeping shimmer fill. */
@Composable
private fun ShimmerBar(
    modifier: Modifier,
    shape: Shape = RoundedCornerShape(SnabbitTheme.borderRadius.sm),
) {
    Box(modifier.clip(shape).shimmer())
}

/**
 * Paints a light streak sweeping left→right over the element's own width. The
 * band is width-aware (captured via [onSizeChanged]) so it reads the same on a
 * 44dp avatar and a full-width bar, and animates on a 1.1s linear loop.
 * Shared with [MoreFromSnabbitSection]'s banner placeholder.
 */
internal fun Modifier.shimmer(): Modifier = composed {
    var widthPx by remember { mutableStateOf(0) }
    val transition = rememberInfiniteTransition(label = "homeShimmer")
    val progress by transition.animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 1100, easing = LinearEasing),
            repeatMode = RepeatMode.Restart,
        ),
        label = "homeShimmerProgress",
    )
    val base = SnabbitTheme.colors.bgTertiary
    val highlight = SnabbitTheme.colors.bgPrimary
    val w = widthPx.toFloat()
    // Band start sweeps from -w to +w; the highlight peak (mid stop) crosses the
    // element as `progress` runs 0→1.
    val bandStart = (progress * 2f - 1f) * w
    val brush = Brush.linearGradient(
        colors = listOf(base, highlight, base),
        start = Offset(bandStart, 0f),
        end = Offset(bandStart + w, 0f),
    )
    this
        .onSizeChanged { widthPx = it.width }
        .background(brush)
}
