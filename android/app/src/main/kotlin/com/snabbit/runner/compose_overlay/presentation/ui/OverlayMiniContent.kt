package com.snabbit.runner.compose_overlay.presentation.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.snabbit.runner.compose_overlay.presentation.model.MiniBreachDisplayModel
import com.snabbit.runner.compose_overlay.presentation.model.awolBreachNudge

/**
 * Compact draggable mini overlay — shown after the user taps "I understood"
 * on the breach dialog. Displays a small countdown/elapsed timer and a
 * one-line warning. Tapping brings the app to the foreground; dragging
 * repositions the pill on screen.
 */
@Composable
fun OverlayMiniContent(
    model: MiniBreachDisplayModel,
    onTap: () -> Unit,
    onTimeout: () -> Unit,
) {
    val isJobMode = model.timerColorMode == "traffic" && model.jobStartTimestampMs != null

    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = OverlayDimens.horizontalPadding)
            .clickable { onTap() },
        shape = RoundedCornerShape(OverlayDimens.miniCardRadius),
        color = OverlayColors.n0,
        shadowElevation = 10.dp,
    ) {
        Row(
            modifier = Modifier.padding(OverlayDimens.miniPadding),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            if (isJobMode) {
                AwolJobTimer(
                    jobStartTimestampMs = model.jobStartTimestampMs!!,
                    arcTotalSeconds = model.totalSeconds,
                    timerSize = OverlayDimens.miniTimerSize,
                    strokeWidth = OverlayDimens.miniTimerStroke,
                    fontSize = 12.sp,
                )
            } else {
                model.triggerAtMs?.let { triggerAtMs ->
                    AwolCountdownTimer(
                        triggerAtMs = triggerAtMs,
                        totalSeconds = model.totalSeconds,
                        onTimeout = { onTimeout() },
                        timerSize = OverlayDimens.miniTimerSize,
                        strokeWidth = OverlayDimens.miniTimerStroke,
                        fontSize = 12.sp,
                        timerColorMode = model.timerColorMode,
                    )
                }
            }

            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(2.dp),
            ) {
                Text(
                    text = model.miniTitle,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.SemiBold,
                    fontFamily = MetropolisFamily,
                    color = OverlayColors.miniTitle,
                    lineHeight = 20.sp,
                )
                if (!model.warningText.isNullOrEmpty()) {
                    Text(
                        text = model.warningText!!,
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Medium,
                        fontFamily = MetropolisFamily,
                        color = OverlayColors.miniSubtext,
                        lineHeight = 18.sp,
                        maxLines = 2,
                    )
                }
                val awolNudge = model.awolBreachNudge
                val nudgeCount = awolNudge?.redCards?.takeIf { it > 0 }
                if (nudgeCount != null) {
                    Spacer(modifier = Modifier.height(4.dp))
                    RedCardPenaltyNudge(
                        redCardCount = nudgeCount,
                        iconUrl = awolNudge!!.iconUrl,
                        nudgeKind = awolNudge.nudgeKind,
                        labelText = awolNudge.labelText,
                        compact = true,
                    )
                }
            }
        }
    }
}
