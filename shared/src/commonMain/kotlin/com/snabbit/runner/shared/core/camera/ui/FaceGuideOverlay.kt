package com.snabbit.runner.shared.core.camera.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.RoundRect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Matrix
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Fill
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.PathParser
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.dp
import com.snabbit.design.theme.SnabbitTheme

/**
 * Head+shoulders silhouette overlay for the selfie capture screen.
 *
 * Renders the exact Figma overlay from `Overlay.svg` (353×519 viewBox):
 * - A semi-transparent dark mask (`rgba(0,0,0,0.2)`) covering everything
 *   OUTSIDE the head+shoulders silhouette
 * - A 3dp dashed white border (dash 8 / gap 6) tracing the silhouette
 * - Clipped to a 24dp rounded rectangle matching the camera preview
 *
 * The SVG path data is converted to a Compose [Path] and scaled
 * proportionally to whatever container size the composable receives.
 *
 * **Conditional:** Only shown when `config.lens == FRONT` and
 * `config.mode == PHOTO`. The caller is responsible for this check —
 * this composable just renders the overlay unconditionally when called.
 *
 * Colors come from `SnabbitTheme` tokens (`whiteDefault` stroke; `blackDefault`
 * at 20% for the mask). The silhouette itself is a camera-specific vector with
 * no DS component equivalent, so it's drawn on a `Canvas`.
 */
@Composable
fun FaceGuideOverlay(
    modifier: Modifier = Modifier,
) {
    val density = LocalDensity.current
    val strokeWidthPx = with(density) { STROKE_WIDTH.toPx() }
    val dashOnPx = with(density) { DASH_ON.toPx() }
    val dashOffPx = with(density) { DASH_OFF.toPx() }
    val cornerRadiusPx = with(density) { CORNER_RADIUS.toPx() }

    // DS tokens (read in composition, used inside the Canvas draw scope).
    val maskColor = SnabbitTheme.colors.bgInverse.copy(alpha = MASK_ALPHA)
    val strokeColor = SnabbitTheme.colors.textInverse

    // Parse the SVG path data and build the base paths once; remember the dash
    // effect too — all hoisted out of the draw scope (previously re-allocated and
    // re-parsed on every draw pass).
    val maskPathBase = remember { PathParser().parsePathString(MASK_PATH_DATA).toPath() }
    val strokePathBase = remember { PathParser().parsePathString(STROKE_PATH_DATA).toPath() }
    val dashEffect = remember(dashOnPx, dashOffPx) {
        PathEffect.dashPathEffect(floatArrayOf(dashOnPx, dashOffPx), phase = 0f)
    }

    Canvas(modifier = modifier.fillMaxSize().clipToBounds()) {
        val canvasWidth = size.width
        val canvasHeight = size.height

        // Scale from SVG viewBox (353×519) to actual canvas size.
        val scaleX = canvasWidth / SVG_WIDTH
        val scaleY = canvasHeight / SVG_HEIGHT
        val scaleMatrix = Matrix().apply { scale(scaleX, scaleY) }

        // Clip to rounded rectangle (matches the 24dp border-radius preview container).
        val clipPath = Path().apply {
            addRoundRect(
                RoundRect(
                    left = 0f,
                    top = 0f,
                    right = canvasWidth,
                    bottom = canvasHeight,
                    cornerRadius = CornerRadius(cornerRadiusPx, cornerRadiusPx),
                )
            )
        }
        drawContext.canvas.save()
        drawContext.canvas.clipPath(clipPath)

        // Path 1: Dark mask — fill only, NO stroke. Copy the remembered base path and
        // scale the copy (transform is in-place, so the shared base can't be scaled).
        val maskPath = Path().apply { addPath(maskPathBase); transform(scaleMatrix) }
        drawPath(path = maskPath, color = maskColor, style = Fill)

        // Path 2: Silhouette border only — the single dashed white stroke, so dash
        // spacing stays consistent everywhere.
        val strokePath = Path().apply { addPath(strokePathBase); transform(scaleMatrix) }
        drawPath(
            path = strokePath,
            color = strokeColor,
            style = Stroke(width = strokeWidthPx, pathEffect = dashEffect),
        )

        drawContext.canvas.restore()
    }
}

// ── SVG path data from Overlay.svg ──────────────────────────────

/** SVG viewBox dimensions (the coordinate space of the path data). */
private const val SVG_WIDTH = 353f
private const val SVG_HEIGHT = 519f

/**
 * Path 1: The dark mask — a closed shape that covers the entire area
 * OUTSIDE the head+shoulders silhouette. Extends beyond the viewBox
 * (negative coords, coords > 353/519) and relies on clip to the
 * rounded rectangle.
 *
 * `fill="black" fill-opacity="0.2"` + `stroke="white" stroke-width="3" stroke-dasharray="8 6"`
 */
private const val MASK_PATH_DATA =
    "M84.7916 197.805" +
    "C84.7916 239.892 101.199 277.034 126.212 299.162" +
    "C124.926 305.637 120.555 312.636 110.228 318.143" +
    "C103.257 321.861 90.5665 326.723 75.5863 332.462" +
    "C35.7834 347.711 -20.1868 369.154 -28.0076 391.793" +
    "C-39.079 417.448 -57.0383 494.032 -62 528.329" +
    "L-53.5 -5.5" +
    "H405.723" +
    "L440.501 528.329" +
    "C435.16 488.337 420.728 405.04 405.723 391.793" +
    "C386.967 375.234 294.201 327.583 249.592 315.417" +
    "C240.419 312.916 236.885 305.271 236.726 296.388" +
    "C260.037 274.005 275.137 238.18 275.137 197.805" +
    "C275.137 129.982 232.527 75 179.964 75" +
    "C127.402 75 84.7916 129.982 84.7916 197.805Z"

/**
 * Path 2: The silhouette border only — traces the head+shoulders
 * outline without the outer rectangle edges. Open path (no Z close).
 *
 * `stroke="white" stroke-width="3" stroke-dasharray="8 6"` (no fill)
 */
private const val STROKE_PATH_DATA =
    "M440.501 528.329" +
    "C435.16 488.337 420.728 405.04 405.723 391.793" +
    "C386.967 375.234 294.201 327.583 249.592 315.417" +
    "C240.419 312.916 236.885 305.271 236.726 296.388" +
    "C260.037 274.005 275.137 238.18 275.137 197.805" +
    "C275.137 129.982 232.527 75 179.964 75" +
    "C127.402 75 84.7916 129.982 84.7916 197.805" +
    "C84.7916 239.892 101.199 277.034 126.212 299.162" +
    "C124.926 305.637 120.555 312.636 110.228 318.143" +
    "C103.257 321.861 90.5666 326.723 75.5863 332.462" +
    "C35.7834 347.711 -20.1868 369.154 -28.0076 391.793" +
    "C-39.079 417.448 -57.0383 494.032 -62 528.329"

// ── Style constants matching the SVG attributes ─────────────────

/** `fill-opacity="0.2"` → blackDefault at 20% alpha. */
private const val MASK_ALPHA = 0.2f

/** `stroke-width="3"` */
private val STROKE_WIDTH = 3.dp

/** `stroke-dasharray="8 6"` — dash on */
private val DASH_ON = 8.dp

/** `stroke-dasharray="8 6"` — dash off */
private val DASH_OFF = 6.dp

/** `clip-path` rect `rx="24"` */
private val CORNER_RADIUS = 24.dp
