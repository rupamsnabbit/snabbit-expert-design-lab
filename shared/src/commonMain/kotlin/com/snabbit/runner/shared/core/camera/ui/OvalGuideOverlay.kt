package com.snabbit.runner.shared.core.camera.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.dp
import com.snabbit.design.theme.SnabbitTheme

/**
 * Dashed portrait-oval guide for the photo capture screen — the generic
 * framing alternative to [FaceGuideOverlay].
 *
 * Placed in the **same 353×519 Figma design frame** as [FaceGuideOverlay] (so the
 * two guides occupy the same region): a 189×257 ellipse, 69px from the top and
 * horizontally centred (→ `cx 176.5 / cy 197.5`, `rx 94.5 / ry 128.5`), drawn as a
 * dashed white border. The frame is scaled to the preview (matching FaceGuide's
 * mapping); stroke weight and dash cadence are fixed dp so both guides read as one
 * system.
 *
 * The stroke uses the `textInverse` token (white on the dark preview); the oval is
 * a camera-specific vector with no DS component, so it's drawn on a `Canvas`.
 */
@Composable
fun OvalGuideOverlay(
    modifier: Modifier = Modifier,
) {
    val density = LocalDensity.current
    val strokeWidthPx = with(density) { STROKE_WIDTH.toPx() }
    val dashOnPx = with(density) { DASH_ON.toPx() }
    val dashOffPx = with(density) { DASH_OFF.toPx() }

    val strokeColor = SnabbitTheme.colors.textInverse
    // Hoisted out of the draw scope — allocated once, not on every draw pass.
    val dashEffect = remember(dashOnPx, dashOffPx) {
        PathEffect.dashPathEffect(floatArrayOf(dashOnPx, dashOffPx), phase = 0f)
    }

    Canvas(modifier = modifier.fillMaxSize()) {
        // Map the 353×519 design frame onto the preview (same frame as
        // FaceGuideOverlay), then place the oval at its design coordinates.
        val scaleX = size.width / FRAME_WIDTH
        val scaleY = size.height / FRAME_HEIGHT
        drawOval(
            color = strokeColor,
            topLeft = Offset(x = OVAL_LEFT * scaleX, y = OVAL_TOP * scaleY),
            size = Size(width = OVAL_WIDTH * scaleX, height = OVAL_HEIGHT * scaleY),
            style = Stroke(width = strokeWidthPx, pathEffect = dashEffect),
        )
    }
}

// ── Spec constants (Figma: 353×519 frame, 189×257 oval, 69px from top) ──────────

/** Design-frame width (shared with [FaceGuideOverlay]). */
private const val FRAME_WIDTH = 353f

/** Design-frame height. */
private const val FRAME_HEIGHT = 519f

/** Oval width within the frame. */
private const val OVAL_WIDTH = 189f

/** Oval height within the frame. */
private const val OVAL_HEIGHT = 257f

/** Oval top offset from the frame top. */
private const val OVAL_TOP = 69f

/** Left offset — horizontally centred in the frame ((353 − 189) / 2 = 82). */
private const val OVAL_LEFT = (FRAME_WIDTH - OVAL_WIDTH) / 2f

/** `stroke-width="3"` */
private val STROKE_WIDTH = 3.dp

/** `stroke-dasharray="8 6"` — dash on */
private val DASH_ON = 8.dp

/** `stroke-dasharray="8 6"` — dash off */
private val DASH_OFF = 6.dp
