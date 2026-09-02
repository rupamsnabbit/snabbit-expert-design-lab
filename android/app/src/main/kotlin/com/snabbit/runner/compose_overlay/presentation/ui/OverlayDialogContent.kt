package com.snabbit.runner.compose_overlay.presentation.ui

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Map
import androidx.compose.material.icons.filled.Navigation
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.snabbit.runner.compose_overlay.presentation.model.BreachDisplayModel
import com.snabbit.runner.compose_overlay.presentation.model.awolBreachNudge


/**
 * Full-screen breach overlay dialog — shown when the expert leaves the hotspot.
 *
 * Displays a map header (CDN image or fallback icon), a countdown timer,
 * warning text, and two CTAs: "Show Directions" (primary) and "I understood" (secondary).
 *
 * The "understood" CTA triggers a transition to the mini overlay on the
 * native side; "show_directions" launches Google Maps and dismisses the overlay.
 */
@Composable
fun OverlayDialogContent(
    model: BreachDisplayModel,
    onAction: (actionId: String, data: Map<String, Any?>) -> Unit,
) {
    val isJobMode = model.timerColorMode == "traffic" && model.jobStartTimestampMs != null
    val awolNudge = model.awolBreachNudge

    // JOB AWOL uses r10 (#F9DADA); BREACH keeps the existing breachGradientStart.
    val gradientStart = if (isJobMode) OverlayColors.r10 else OverlayColors.breachGradientStart

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = OverlayDimens.horizontalPadding)
            .clip(RoundedCornerShape(OverlayDimens.cardRadius))
            .background(
                if (isJobMode) {
                    SolidColor(OverlayColors.r10)
                } else {
                    Brush.verticalGradient(
                        colors = listOf(gradientStart, OverlayColors.n0),
                    )
                }
            ),
    ) {
        // Map image — no badge inside
        MapSection(
            mapBackgroundColor = gradientStart.copy(alpha = 0.5f),
            mapIconTint = OverlayColors.r20,
            gradientColor = gradientStart,
            imageUrl = model.imageUrl,
        )

        // Status pill — always shown between map and timer.
        // First timer (no red cards): shows badgeText e.g. "OUTSIDE HOTSPOT".
        // After penalty (redCardCount > 0): shows "N RED CARD(S) RECEIVED" with icon.
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 14.dp),
            contentAlignment = Alignment.Center,
        ) {
            val receivedCount = model.redCardsTotal?.takeIf { it > 0 }
            if (receivedCount != null) {
                Row(
                    modifier = Modifier
                        .background(OverlayColors.n0, CircleShape)
                        .padding(horizontal = 16.dp, vertical = 6.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    val iconUrl = awolNudge?.iconUrl?.takeIf { it.isNotBlank() }
                    if (iconUrl != null) {
                        coil.compose.AsyncImage(
                            model = coil.request.ImageRequest.Builder(androidx.compose.ui.platform.LocalContext.current)
                                .data(iconUrl)
                                .allowHardware(false)
                                .build(),
                            contentDescription = null,
                            modifier = Modifier.size(12.dp),
                        )
                    }
                    Text(
                        text = "$receivedCount ${model.redCardReceivedLabel}",
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Bold,
                        fontFamily = MetropolisFamily,
                        color = OverlayColors.r50,
                        letterSpacing = 0.5.sp,
                        lineHeight = 16.sp,
                    )
                }
            } else {
                Box(
                    modifier = Modifier
                        .background(OverlayColors.n0, CircleShape)
                        .padding(horizontal = 16.dp, vertical = 4.dp),
                ) {
                    Text(
                        text = model.badgeText,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Bold,
                        fontFamily = MetropolisFamily,
                        color = OverlayColors.r50,
                        letterSpacing = 0.5.sp,
                        lineHeight = 16.sp,
                    )
                }
            }
        }

        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = OverlayDimens.horizontalPadding),
        ) {
            Spacer(modifier = Modifier.height(15.dp))

            if (!model.title.isNullOrEmpty()) {
                Text(
                    text = model.title,
                    textAlign = TextAlign.Center,
                    fontSize = 18.sp,
                    fontWeight = FontWeight.SemiBold,
                    fontFamily = MetropolisFamily,
                    color = OverlayColors.r60,
                    lineHeight = 24.sp,
                )
            }

            Spacer(modifier = Modifier.height(20.dp))

            if (isJobMode) {
                AwolJobTimer(
                    jobStartTimestampMs = model.jobStartTimestampMs!!,
                    arcTotalSeconds = model.totalSeconds,
                )
            } else {
                model.triggerAtMs?.let { triggerAtMs ->
                    AwolCountdownTimer(
                        triggerAtMs = triggerAtMs,
                        totalSeconds = model.totalSeconds,
                        onTimeout = { onAction("timeout", emptyMap()) },
                        timerColorMode = model.timerColorMode,
                    )
                }
            }

            Spacer(modifier = Modifier.height(20.dp))

            if (!model.warningText.isNullOrEmpty()) {
                Text(
                    text = model.warningText,
                    textAlign = TextAlign.Center,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Medium,
                    fontFamily = MetropolisFamily,
                    color = OverlayColors.r60,
                    lineHeight = 18.sp,
                )
            }
        }

        val nudgeCount = awolNudge?.redCards?.takeIf { it > 0 }
        if (nudgeCount != null) {
            Spacer(modifier = Modifier.height(12.dp))
            RedCardPenaltyNudge(
                redCardCount = nudgeCount,
                iconUrl = awolNudge!!.iconUrl,
                nudgeKind = awolNudge.nudgeKind,
                labelText = awolNudge.labelText,
                outsideHotspotLabel = model.nudgeOutsideHotspot,
                modifier = Modifier.padding(horizontal = OverlayDimens.horizontalPadding),
            )
        }

        Spacer(modifier = Modifier.height(20.dp))

        // Buttons
        Column(
            modifier = Modifier.padding(start = 20.dp, end = 20.dp, bottom = 20.dp),
        ) {
            if (model.primaryButton != null) {
                Button(
                    onClick = { onAction(model.primaryButton.actionId, model.primaryButton.data) },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(OverlayDimens.buttonHeight),
                    shape = RoundedCornerShape(OverlayDimens.buttonRadius),
                    colors = ButtonDefaults.buttonColors(containerColor = OverlayColors.n90),
                    elevation = ButtonDefaults.buttonElevation(defaultElevation = 0.dp),
                ) {
                    Icon(
                        Icons.Default.Navigation,
                        contentDescription = null,
                        modifier = Modifier.size(14.dp),
                        tint = OverlayColors.n0,
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = model.primaryButton.label,
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Bold,
                        fontFamily = MetropolisFamily,
                        color = OverlayColors.n0,
                    )
                }
                Spacer(modifier = Modifier.height(12.dp))
            }

            val secondaryLabel = model.secondaryButton?.label ?: "I understood"
            val secondaryActionId = model.secondaryButton?.actionId ?: "understood"

            OutlinedButton(
                onClick = { onAction(secondaryActionId, emptyMap()) },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(OverlayDimens.buttonHeight),
                shape = RoundedCornerShape(OverlayDimens.buttonRadius),
                border = BorderStroke(1.dp, OverlayColors.n90),
            ) {
                Text(
                    text = secondaryLabel,
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Bold,
                    fontFamily = MetropolisFamily,
                    color = OverlayColors.n90,
                )
            }
        }
    }
}

@Composable
internal fun MapSection(
    mapBackgroundColor: Color,
    mapIconTint: Color,
    gradientColor: Color,
    imageUrl: String? = null,
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(OverlayDimens.mapHeight)
            .clip(RoundedCornerShape(topStart = OverlayDimens.cardRadius, topEnd = OverlayDimens.cardRadius))
            .background(mapBackgroundColor),
    ) {
        if (!imageUrl.isNullOrEmpty()) {
            coil.compose.AsyncImage(
                model = coil.request.ImageRequest.Builder(androidx.compose.ui.platform.LocalContext.current)
                    .data(imageUrl)
                    .allowHardware(false)
                    .build(),
                contentDescription = null,
                modifier = Modifier.fillMaxSize(),
                contentScale = androidx.compose.ui.layout.ContentScale.Crop,
            )
        } else {
            Icon(
                Icons.Default.Map,
                contentDescription = null,
                modifier = Modifier
                    .size(80.dp)
                    .align(Alignment.Center),
                tint = mapIconTint,
            )
        }

        Box(
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .fillMaxWidth()
                .height(42.dp)
                .background(
                    Brush.verticalGradient(
                        colors = listOf(gradientColor.copy(alpha = 0f), gradientColor),
                    )
                ),
        )
    }
}
