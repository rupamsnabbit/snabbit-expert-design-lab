package com.snabbit.runner.compose_overlay.presentation.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.sp
import kotlin.math.abs
import kotlinx.coroutines.delay

/**
 * Job-AWOL timer for the native overlay. Anchored to an absolute UTC
 * timestamp ([jobStartTimestampMs]) so it survives overlay rebuilds — no
 * "5-min reset" when the backend re-emits AWOL with a new `detected_at`.
 *
 * Behavior parity with the FG `CircularTimerWidget` (no showLateBlinking):
 *  - Counts down to the job's start moment, then continues into negative
 *    time (`-MM:SS`). The red traffic-light color is the lateness signal.
 *
 * Visual semantics:
 *  - The progress arc is scaled by [arcTotalSeconds] (just for the ring's
 *    color/fill) and clamped to [0, 1]. When time is past the start, the
 *    arc collapses to 0 and the traffic-light color resolves to red.
 */
@Composable
fun AwolJobTimer(
    jobStartTimestampMs: Long,
    arcTotalSeconds: Int,
    modifier: Modifier = Modifier,
    timerSize: Dp = OverlayDimens.timerSize,
    strokeWidth: Dp = OverlayDimens.timerStroke,
    fontSize: TextUnit = 30.sp,
) {
    var nowMs by remember { mutableLongStateOf(System.currentTimeMillis()) }

    LaunchedEffect(jobStartTimestampMs) {
        // Tick at wall-clock second boundaries. Recomputing nowMs (rather than
        // decrementing a counter) makes the timer immune to overlay rebuilds —
        // every recomposition derives from the same absolute jobStartTimestampMs.
        // Ticking past the start shows negative elapsed time, matching the
        // foreground CircularTimerWidget behaviour.
        while (true) {
            nowMs = System.currentTimeMillis()
            val nextTickMs = ((nowMs / 1000) + 1) * 1000
            delay(maxOf(0L, nextTickMs - System.currentTimeMillis()))
        }
    }

    val remainingSec = ((jobStartTimestampMs - nowMs) / 1000L).toInt()
    val isNegative = remainingSec < 0
    val absSec = abs(remainingSec)
    val timeText = "%s%02d:%02d".format(if (isNegative) "-" else "", absSec / 60, absSec % 60)

    val progress = if (arcTotalSeconds > 0) {
        (remainingSec.toFloat() / arcTotalSeconds).coerceIn(0f, 1f)
    } else 0f
    val colors = resolveTimerColors(progress, "traffic")

    Box(
        contentAlignment = Alignment.Center,
        modifier = modifier.size(timerSize),
    ) {
        Canvas(modifier = Modifier.matchParentSize()) {
            val stroke = strokeWidth.toPx()
            val radius = (size.minDimension - stroke) / 2
            val topLeft = Offset(
                (size.width - radius * 2) / 2,
                (size.height - radius * 2) / 2,
            )
            val arcSize = Size(radius * 2, radius * 2)

            drawCircle(
                color = colors.bg,
                radius = radius,
                style = Stroke(width = stroke, cap = StrokeCap.Round),
            )

            if (progress > 0f) {
                drawArc(
                    color = colors.arc,
                    startAngle = -90f,
                    sweepAngle = 360f * progress,
                    useCenter = false,
                    topLeft = topLeft,
                    size = arcSize,
                    style = Stroke(width = stroke, cap = StrokeCap.Round),
                )
            }
        }

        Text(
            text = timeText,
            fontSize = fontSize,
            fontWeight = FontWeight.Bold,
            fontFamily = MetropolisFamily,
            color = colors.text,
        )
    }
}
