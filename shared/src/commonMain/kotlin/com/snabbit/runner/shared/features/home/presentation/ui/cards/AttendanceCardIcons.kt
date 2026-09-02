@file:Suppress("ForbiddenImport") // Color.White vector-path fills for inline illustrations — DS has no illustration asset (DS_GAPS.md §assets)

package com.snabbit.runner.shared.features.home.presentation.ui.cards

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.path
import androidx.compose.ui.unit.dp

/**
 * Local AttendanceCard icons that don't exist in DS 0.11.0 — Figma's
 * Absent / Present buttons use a circled X and circled check that the
 * built-in [com.snabbit.design.atoms.SnabbitIconName] set doesn't ship.
 *
 * Used via the [com.snabbit.design.atoms.SnabbitIcon] `imageVector` overload
 * (DS's official escape hatch for one-off icons).
 *
 * ponytail: hand-rolled here per `CLAUDE.md` rules — "If nothing fits…
 * hand-roll locally + file a DS ticket." When DS adds `CheckCircle` /
 * `XCircle` (or `CloseCircle`) names, delete this file and switch the
 * call sites to the named overload.
 *
 * Stroke geometry mirrors the Figma DS icon SVGs (20×20 viewBox, white
 * stroke, 1.667px width, round caps + joins). Color comes from the
 * `SnabbitIcon` `color` parameter — paths use [Color.White] only so that
 * the icon tints correctly when rendered inside a coloured button.
 */
internal val AbsentCircleIcon: ImageVector by lazy {
    ImageVector.Builder(
        name = "AbsentCircle",
        defaultWidth = 20.dp,
        defaultHeight = 20.dp,
        viewportWidth = 20f,
        viewportHeight = 20f,
    ).apply {
        // Outer circle.
        circlePath()
        // Cross stroke 1: top-right → bottom-left.
        strokePath {
            moveTo(12.5f, 7.5f)
            lineTo(7.5f, 12.5f)
        }
        // Cross stroke 2: top-left → bottom-right.
        strokePath {
            moveTo(7.5f, 7.5f)
            lineTo(12.5f, 12.5f)
        }
    }.build()
}

internal val PresentCircleIcon: ImageVector by lazy {
    ImageVector.Builder(
        name = "PresentCircle",
        defaultWidth = 20.dp,
        defaultHeight = 20.dp,
        viewportWidth = 20f,
        viewportHeight = 20f,
    ).apply {
        // Outer circle.
        circlePath()
        // Check stroke: down-stroke into the v, then up-stroke to the right.
        strokePath {
            moveTo(6.25f, 10.42f)
            lineTo(9.17f, 13.33f)
            lineTo(14.17f, 7.5f)
        }
    }.build()
}

// ───────────────── helpers ─────────────────

private fun ImageVector.Builder.circlePath(): ImageVector.Builder {
    strokePath {
        // Cubic-bezier approximation of a 20-unit circle, matching the Figma
        // SVG path data verbatim (offset 1.667, radius 8.333).
        moveTo(10.0013f, 18.3346f)
        curveTo(14.6037f, 18.3346f, 18.3346f, 14.6037f, 18.3346f, 10.0013f)
        curveTo(18.3346f, 5.39893f, 14.6037f, 1.66797f, 10.0013f, 1.66797f)
        curveTo(5.39893f, 1.66797f, 1.66797f, 5.39893f, 1.66797f, 10.0013f)
        curveTo(1.66797f, 14.6037f, 5.39893f, 18.3346f, 10.0013f, 18.3346f)
        close()
    }
    return this
}

private fun ImageVector.Builder.strokePath(
    block: androidx.compose.ui.graphics.vector.PathBuilder.() -> Unit,
): ImageVector.Builder = apply {
    path(
        fill = null,
        stroke = SolidColor(Color.White),
        strokeLineWidth = 1.667f,
        strokeLineCap = StrokeCap.Round,
        strokeLineJoin = StrokeJoin.Round,
        pathBuilder = block,
    )
}
