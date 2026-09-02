package com.snabbit.runner.shared.features.gamification.presentation.postaction

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutLinearInEasing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.BlurredEdgeTreatment
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.snabbit.design.atoms.SnabbitRemoteImage
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.theme.SnabbitColorsLight
import com.snabbit.runner.shared.features.gamification.domain.model.PostActionOutcome
import com.snabbit.runner.shared.features.gamification.presentation.ResolveNudgeLabel
import com.snabbit.runner.shared.resources.Res
import com.snabbit.runner.shared.resources.red_card_display
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import org.jetbrains.compose.resources.painterResource
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin

/**
 * Full-screen post-action reward / penalty popup — the KMP port of Dart
 * `lib/widgets/gamification/post_action_popup.dart` (+ soft-starburst / ellipse
 * bloom). Rendered over a dimmed scrim by [PostActionOverlayHost]; invokes
 * [onComplete] (→ [PostActionCoordinator.dismiss]) when the sequence finishes or
 * the scrim is tapped.
 *
 * Sequence mirrors Dart 1:1 up to the exit:
 *  1. **reveal / idle** — the N-asset cluster (coins or -50 cards, grid of max 3
 *     per row, overlapping when > 2) pulses 1.0↔1.12 (500ms/leg) behind a rotating
 *     soft-starburst + ellipse bloom, with the parallelogram title ribbon below.
 *  2. **settle** — pulse eases back to 1.0, then a 1s hold.
 *  3. **exit** — KMP-specific: the whole popup **shrinks and fades away**
 *     (Dart instead flies the coins to the header pill). This is the only
 *     intentional difference from Dart.
 *
 * Known parity gaps (platform / DS, not behavioural): the Dart 4px backdrop blur
 * of the content *behind* the overlay isn't reproducible in commonMain (we use
 * the black-50% scrim only); the ribbon uses the DS Outfit face rather than Dart's
 * Metropolis; glow outset positioning is centred on the cluster rather than
 * measured.
 */
@Composable
fun PostActionPopup(
    outcome: PostActionOutcome,
    onComplete: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val isReward = outcome.isReward
    val count = (if (isReward) outcome.goldCoins else outcome.redCards).coerceIn(1, 9)
    val assetSize = sizeForCount(count)

    // Cluster pulse (idle) and whole-popup exit shrink/fade.
    val pulse = remember(outcome) { Animatable(1f) }
    val exitScale = remember(outcome) { Animatable(1f) }
    val exitAlpha = remember(outcome) { Animatable(1f) }

    LaunchedEffect(outcome) {
        val pulseJob = launch {
            // Oscillate 1.0↔1.12 with easeInOut, matching Dart's 500ms-per-leg pulse.
            while (isActive) {
                pulse.animateTo(1.12f, tween(PULSE_MS))
                pulse.animateTo(1f, tween(PULSE_MS))
            }
        }
        delay(idleMsForCount(count))
        pulseJob.cancel()
        pulse.animateTo(1f, tween(PULSE_MS, easing = LinearEasing)) // settle
        delay(HOLD_MS)
        // Exit — shrink + fade the whole popup (KMP's replacement for the flight).
        launch { exitAlpha.animateTo(0f, tween(EXIT_MS)) }
        exitScale.animateTo(EXIT_SCALE, tween(EXIT_MS, easing = FastOutLinearInEasing))
        onComplete()
    }

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.5f))
            .clickable(onClick = onComplete),
        contentAlignment = Alignment.Center,
    ) {
        Box(
            // Slightly above centre (Dart pads 12 below), shrink+fade on exit.
            modifier = Modifier
                .padding(bottom = 12.dp)
                .graphicsLayer {
                    scaleX = exitScale.value
                    scaleY = exitScale.value
                    alpha = exitAlpha.value
                },
            contentAlignment = Alignment.Center,
        ) {
            // Glow backdrop, centred on the cluster (Figma Star 35 → Ellipse 13967).
            GlowBackdrop(isReward = isReward, modifier = Modifier.size(GLOW_SIZE))

            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                AssetCluster(
                    isReward = isReward,
                    count = count,
                    assetSize = assetSize,
                    modifier = Modifier.graphicsLayer {
                        scaleX = pulse.value
                        scaleY = pulse.value
                    },
                )
                Spacer(Modifier.height(24.dp))
                TitleRibbon(
                    isReward = isReward,
                    label = ResolveNudgeLabel.resolve(outcome.label).replace("**", "").uppercase(),
                    iconUrl = outcome.iconUrl,
                )
            }
        }
    }
}

// ── Glow backdrop: rotating soft starburst + blurred ellipse bloom ─────────────

@Composable
private fun GlowBackdrop(isReward: Boolean, modifier: Modifier = Modifier) {
    Box(modifier = modifier, contentAlignment = Alignment.Center) {
        SoftStarburst(isReward = isReward, modifier = Modifier.fillMaxSize())
        EllipseBloom(isReward = isReward)
    }
}

/** Figma Ellipse 13967: a 300dp circle @50%, blur 70. Sits above the rays.
 *  Unbounded edge treatment so the blur fades past the circle instead of being
 *  clipped to a hard-edged box. */
@Composable
private fun EllipseBloom(isReward: Boolean) {
    val color = if (isReward) BLOOM_REWARD else BLOOM_PENALTY
    Box(
        modifier = Modifier
            .size(300.dp)
            .blur(70.dp, edgeTreatment = BlurredEdgeTreatment.Unbounded)
            .background(color, androidx.compose.foundation.shape.CircleShape),
    )
}

/** Figma Star 35: 10 petal rays fading to transparent, slow 8s rotation, light blur. */
@Composable
private fun SoftStarburst(isReward: Boolean, modifier: Modifier = Modifier) {
    val rotation by rememberInfiniteTransition(label = "starburst").animateFloat(
        initialValue = 0f,
        targetValue = 360f,
        animationSpec = infiniteRepeatable(tween(8_000, easing = LinearEasing)),
        label = "rotation",
    )
    val hub = if (isReward) STAR_HUB_REWARD else STAR_HUB_PENALTY
    val mid = if (isReward) STAR_MID_REWARD else STAR_MID_PENALTY

    Canvas(
        modifier = modifier
            .graphicsLayer { rotationZ = rotation }
            .blur(1.8.dp),
    ) {
        val center = Offset(size.width / 2f, size.height / 2f)
        val rMax = min(size.width, size.height) * 0.38f
        val halfAngle = (PI / RAYS * 0.70).toFloat()
        val rCtrl = rMax * 0.45f

        for (i in 0 until RAYS) {
            val a0 = (-PI / 2 + i * 2 * PI / RAYS).toFloat()
            val tip = Offset(center.x + rMax * cos(a0), center.y + rMax * sin(a0))
            val path = Path().apply {
                moveTo(center.x, center.y)
                quadraticBezierTo(
                    center.x + rCtrl * cos(a0 - halfAngle),
                    center.y + rCtrl * sin(a0 - halfAngle),
                    tip.x, tip.y,
                )
                quadraticBezierTo(
                    center.x + rCtrl * cos(a0 + halfAngle),
                    center.y + rCtrl * sin(a0 + halfAngle),
                    center.x, center.y,
                )
                close()
            }
            drawPath(
                path = path,
                brush = Brush.linearGradient(
                    0.0f to hub.copy(alpha = 0.12f),
                    0.55f to mid.copy(alpha = 0.05f),
                    1.0f to mid.copy(alpha = 0f),
                    start = center,
                    end = tip,
                ),
            )
        }
        // Subtle nucleus glow.
        drawCircle(
            brush = Brush.radialGradient(
                listOf(hub.copy(alpha = 0.08f), hub.copy(alpha = 0f)),
                center = center,
                radius = rMax * 0.14f,
            ),
            radius = rMax * 0.14f,
            center = center,
        )
    }
}

// ── Asset cluster (coins / -50 cards), rows of max 3, overlap when > 2 ──────────

@Composable
private fun AssetCluster(
    isReward: Boolean,
    count: Int,
    assetSize: androidx.compose.ui.unit.Dp,
    modifier: Modifier = Modifier,
) {
    val rows = (0 until count step 3).map { start -> (start until min(start + 3, count)).toList() }
    Column(modifier = modifier, horizontalAlignment = Alignment.CenterHorizontally) {
        rows.forEachIndexed { r, indices ->
            if (r > 0) Spacer(Modifier.height(4.dp))
            AssetRow(isReward = isReward, size = indices.size, assetSize = assetSize)
        }
    }
}

@Composable
private fun AssetRow(isReward: Boolean, size: Int, assetSize: androidx.compose.ui.unit.Dp) {
    if (size <= 2) {
        Row {
            repeat(size) {
                Asset(isReward, assetSize, Modifier.padding(horizontal = 4.dp))
            }
        }
    } else {
        // Overlap: each successive asset shifted by 70% of its size (Dart parity).
        val step = assetSize * 0.70f
        Box(modifier = Modifier.width(assetSize + step * (size - 1)).height(assetSize)) {
            repeat(size) { j ->
                Asset(isReward, assetSize, Modifier.offset(x = step * j))
            }
        }
    }
}

@Composable
private fun Asset(isReward: Boolean, assetSize: androidx.compose.ui.unit.Dp, modifier: Modifier = Modifier) {
    if (isReward) {
        SnabbitRemoteImage(
            model = GOLD_COIN_URL,
            contentDescription = null,
            modifier = modifier.size(assetSize),
            contentScale = ContentScale.Fit,
        )
    } else {
        Image(
            painter = painterResource(Res.drawable.red_card_display),
            contentDescription = null,
            modifier = modifier.size(assetSize),
            contentScale = ContentScale.Fit,
        )
    }
}

// ── Parallelogram title ribbon (Figma reward 7059:30990 / penalty 6705:145668) ──

@Composable
private fun TitleRibbon(isReward: Boolean, label: String, iconUrl: String?) {
    val ribbonColor = if (isReward) SnabbitColorsLight.yellow700 else SnabbitColorsLight.red700
    val shape = remember {
        androidx.compose.foundation.shape.GenericShape { s, _ ->
            val skew = s.height * RIBBON_SKEW
            moveTo(skew, 0f)
            lineTo(s.width, 0f)
            lineTo(s.width - skew, s.height)
            lineTo(0f, s.height)
            close()
        }
    }
    Row(
        modifier = Modifier
            .height(25.dp)
            .clip(shape)
            .background(ribbonColor)
            .padding(horizontal = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        RibbonLeadingIcon(url = iconUrl)
        Spacer(Modifier.width(7.dp))
        SnabbitText(
            text = label,
            color = SnabbitColorsLight.yellow50,
            fontSize = 14.sp,
            lineHeight = 14.sp,
            fontWeight = FontWeight.Bold,
        )
    }
}

/** 16dp leading slot: network image from [url], or the solid cream dot when unset. */
@Composable
private fun RibbonLeadingIcon(url: String?) {
    val clean = url?.trim()
    if (clean.isNullOrEmpty()) {
        Box(
            modifier = Modifier
                .size(16.dp)
                .background(SnabbitColorsLight.yellow50, androidx.compose.foundation.shape.CircleShape),
        )
    } else {
        SnabbitRemoteImage(
            model = clean,
            contentDescription = null,
            modifier = Modifier.size(16.dp),
            contentScale = ContentScale.Fit,
        )
    }
}

// ── constants ──────────────────────────────────────────────────────────────────

/** Asset size scales down as more items show (Dart `_sizeForCount`, sp→dp). */
private fun sizeForCount(count: Int) = when {
    count <= 1 -> 120.dp
    count <= 2 -> 100.dp
    count <= 4 -> 85.dp
    count <= 6 -> 75.dp
    else -> 65.dp
}

/** Idle pulse duration — shorter for higher counts so the sequence stays snappy. */
private fun idleMsForCount(count: Int): Long = when {
    count <= 2 -> 750L
    count <= 4 -> 650L
    else -> 550L
}

private const val PULSE_MS = 500
private const val HOLD_MS = 1_000L
private const val EXIT_MS = 400
private const val EXIT_SCALE = 0.6f
private const val RIBBON_SKEW = 0.2f
private const val RAYS = 10
private const val PI = kotlin.math.PI

private const val GOLD_COIN_URL =
    "https://assets-expert.snabbit.com/payouts/nudges/gold_coin_straight.png"

// Bespoke Figma glow colours — not DS tokens (this effect isn't in the palette).
private val BLOOM_REWARD = Color(0x80FFB400)
private val BLOOM_PENALTY = Color(0x80FA3838)
private val STAR_HUB_REWARD = Color(0xFFFFF9F0)
private val STAR_MID_REWARD = Color(0xFFFFF2DC)
private val STAR_HUB_PENALTY = Color(0xFFFFFBFB)
private val STAR_MID_PENALTY = Color(0xFFFFE8E8)
private val GLOW_SIZE = 360.dp
