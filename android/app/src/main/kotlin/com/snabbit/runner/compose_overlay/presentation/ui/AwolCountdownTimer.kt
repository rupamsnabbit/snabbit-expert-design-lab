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
import kotlinx.coroutines.delay

/**
 * Circular countdown timer for the AWOL breach overlay.
 *
 * Remaining time is derived from `totalSeconds - (now - triggerAtMs) / 1000`
 * on every recomposition — always wall-clock accurate regardless of when the
 * composable is recomposed. The coroutine is a tick trigger only; it does not
 * own the time state.
 */
@Composable
fun AwolCountdownTimer(
    triggerAtMs: Long,
    totalSeconds: Int,
    onTimeout: () -> Unit,
    modifier: Modifier = Modifier,
    timerColorMode: String = "red",
    timerSize: Dp = OverlayDimens.timerSize,
    strokeWidth: Dp = OverlayDimens.timerStroke,
    fontSize: TextUnit = 30.sp,
) {
    fun computeRemaining(): Int =
        ((triggerAtMs - System.currentTimeMillis()) / 1000).toInt().coerceIn(0, totalSeconds)

    // Incremented every second; read below so Compose tracks it as a composition dependency.
    var tick by remember { mutableIntStateOf(0) }
    val currentOnTimeout by rememberUpdatedState(onTimeout)

    LaunchedEffect(triggerAtMs) {
        while (computeRemaining() > 0) {
            delay(1000)
            tick++
        }
        currentOnTimeout()
    }

    // remember(tick) re-evaluates computeRemaining() on every tick increment,
    // which is what creates the actual recomposition dependency on `tick`.
    val remaining = remember(tick) { computeRemaining() }
    val progress = if (totalSeconds > 0) remaining.toFloat() / totalSeconds else 0f
    val colors = resolveTimerColors(progress, timerColorMode)
    val minutes = remaining / 60
    val seconds = remaining % 60
    val timeText = "%02d:%02d".format(minutes, seconds)

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
