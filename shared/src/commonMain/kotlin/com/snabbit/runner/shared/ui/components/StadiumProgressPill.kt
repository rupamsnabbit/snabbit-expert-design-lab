package com.snabbit.runner.shared.ui.components

import androidx.compose.foundation.layout.Box
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathMeasure
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

// `androidx.compose.ui.graphics.Color` is written fully-qualified below rather than imported —
// the shared detekt `ForbiddenImport` rule bans the import so screens use SnabbitTheme tokens.
// A generic drawing primitive legitimately takes caller-supplied colors, so it accepts the type
// by full name.

/**
 * Generic stadium/pill progress ring: strokes a full [trackColor] outline with the [progress]
 * fraction (0..1) drawn over it in [progressColor], and centers arbitrary [content] (e.g. a
 * label + time). The caller owns the content layout and its text, so each usage keeps its own
 * look; size comes from [modifier].
 *
 * The ring sweeps from **top-center, clockwise** — the job in-progress timer's appearance
 * (Figma "Timers" 371:6294). Both the job in-progress pill and the AWOL countdown meter share
 * this one implementation so they look and animate the same way. (This intentionally differs
 * from the design-system `SnabbitPillProgress`, whose left-start sweep and variant palette suit
 * the check-in timers — that molecule is left untouched.) commonMain-pure.
 */
@Composable
fun StadiumProgressPill(
    progress: Float,
    trackColor: androidx.compose.ui.graphics.Color,
    progressColor: androidx.compose.ui.graphics.Color,
    modifier: Modifier = Modifier,
    strokeWidth: Dp = 6.dp,
    content: @Composable () -> Unit,
) {
    val fraction = progress.coerceIn(0f, 1f)
    Box(
        modifier = modifier.drawBehind {
            val sw = strokeWidth.toPx()
            val inset = sw / 2f
            val w = size.width
            val h = size.height
            if (w <= sw || h <= sw) return@drawBehind
            val r = minOf(90.dp.toPx(), (h - sw) / 2f, (w - sw) / 2f)
            if (r <= 0f) return@drawBehind
            val cx = w / 2f

            // Top-center start, winding clockwise, so getSegment(0 … len·progress) fills
            // clockwise from the top — matching the Figma timer.
            val path = Path().apply {
                moveTo(cx, inset)                    // top-center
                lineTo(w - inset - r, inset)         // top edge → right cap
                arcTo(Rect(w - inset - 2f * r, inset, w - inset, h - inset), -90f, 180f, false)
                lineTo(inset + r, h - inset)         // bottom edge (right → left)
                arcTo(Rect(inset, inset, inset + 2f * r, h - inset), 90f, 180f, false)
                lineTo(cx, inset)                    // top edge left half → back to start
            }

            drawPath(path, color = trackColor, style = Stroke(width = sw))
            if (fraction > 0f) {
                val measure = PathMeasure().apply { setPath(path, forceClosed = false) }
                val segment = Path()
                measure.getSegment(0f, measure.length * fraction, segment, true)
                drawPath(
                    segment,
                    color = progressColor,
                    style = Stroke(width = sw, cap = StrokeCap.Round),
                )
            }
        },
        contentAlignment = Alignment.Center,
    ) {
        content()
    }
}
