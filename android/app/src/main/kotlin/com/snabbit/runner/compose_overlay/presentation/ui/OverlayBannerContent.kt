package com.snabbit.runner.compose_overlay.presentation.ui

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.WarningAmber
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.SubcomposeAsyncImage
import coil.compose.SubcomposeAsyncImageContent
import com.snabbit.runner.compose_overlay.domain.ConsequenceConfig
import com.snabbit.runner.compose_overlay.presentation.model.ReEnteredDisplayModel

/**
 * Re-entered state overlay banner — shown when the expert returns to the hotspot
 * while the app is in the background.
 *
 * Displays a map header with a green gradient, a success-style message, an
 * optional list of consequences (icons + text loaded from CDN), and an
 * "I understood" dismiss button.
 */
@Composable
fun OverlayBannerContent(
    model: ReEnteredDisplayModel,
    onAction: (actionId: String, data: Map<String, Any?>) -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = OverlayDimens.horizontalPadding)
            .clip(RoundedCornerShape(OverlayDimens.cardRadius))
            .background(
                Brush.verticalGradient(
                    colorStops = arrayOf(
                        0.0f to OverlayColors.reEnteredGradientStart,
                        0.61f to OverlayColors.n0,
                    ),
                )
            ),
    ) {
        MapSection(
            mapBackgroundColor = OverlayColors.reEnteredGradientStart.copy(alpha = 0.5f),
            mapIconTint = OverlayColors.g20,
            gradientColor = OverlayColors.reEnteredGradientStart,
            imageUrl = model.imageUrl,
        )

        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 14.dp),
            contentAlignment = Alignment.Center,
        ) {
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
                    color = OverlayColors.g40,
                    letterSpacing = 0.5.sp,
                    lineHeight = 16.sp,
                )
            }
        }

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f, fill = false)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = OverlayDimens.horizontalPadding),
        ) {
            Spacer(modifier = Modifier.height(14.dp))

            if (!model.title.isNullOrEmpty()) {
                Text(
                    text = model.title,
                    textAlign = TextAlign.Center,
                    fontSize = 22.sp,
                    fontWeight = FontWeight.Bold,
                    fontFamily = MetropolisFamily,
                    color = OverlayColors.g40,
                    modifier = Modifier.fillMaxWidth(),
                )
            }

            Spacer(modifier = Modifier.height(20.dp))

            if (!model.warningText.isNullOrEmpty()) {
                Text(
                    text = model.warningText,
                    textAlign = TextAlign.Center,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Medium,
                    fontFamily = MetropolisFamily,
                    color = OverlayColors.n80,
                    lineHeight = 20.sp,
                    modifier = Modifier.fillMaxWidth(),
                )
            }

            if (model.consequences.isNotEmpty()) {
                Spacer(modifier = Modifier.height(24.dp))

                model.consequences.forEachIndexed { index, consequence ->
                    ConsequenceItem(consequence)
                    if (index < model.consequences.lastIndex) {
                        HorizontalDivider(
                            modifier = Modifier.padding(vertical = 10.dp),
                            thickness = 1.dp,
                            color = OverlayColors.n30,
                        )
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(20.dp))

        OutlinedButton(
            onClick = { onAction(model.button?.actionId ?: "understood", emptyMap()) },
            modifier = Modifier
                .fillMaxWidth()
                .height(OverlayDimens.buttonHeight)
                .padding(horizontal = 20.dp),
            shape = RoundedCornerShape(OverlayDimens.buttonRadius),
            border = BorderStroke(1.dp, OverlayColors.n90),
        ) {
            Text(
                text = model.button?.label ?: "I understood",
                fontSize = 13.sp,
                fontWeight = FontWeight.Bold,
                fontFamily = MetropolisFamily,
                color = OverlayColors.n90,
            )
        }

        Spacer(modifier = Modifier.height(20.dp))
    }
}

@Composable
private fun ConsequenceItem(consequence: ConsequenceConfig) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Box(
            modifier = Modifier
                .size(OverlayDimens.consequenceIconSize)
                .clip(CircleShape)
                .background(OverlayColors.n20),
            contentAlignment = Alignment.Center,
        ) {
            if (!consequence.iconUrl.isNullOrEmpty()) {
                SubcomposeAsyncImage(
                    model = coil.request.ImageRequest.Builder(androidx.compose.ui.platform.LocalContext.current)
                        .data(consequence.iconUrl)
                        .allowHardware(false)
                        .build(),
                    contentDescription = null,
                    modifier = Modifier.size(OverlayDimens.consequenceIconSize),
                    contentScale = ContentScale.Crop,
                    error = {
                        Icon(
                            Icons.Default.WarningAmber,
                            contentDescription = null,
                            modifier = Modifier.size(24.dp),
                            tint = OverlayColors.n80,
                        )
                    },
                    success = { SubcomposeAsyncImageContent() },
                )
            }
        }

        Spacer(modifier = Modifier.width(12.dp))

        Text(
            text = consequence.text ?: "",
            fontSize = 14.sp,
            fontWeight = FontWeight.SemiBold,
            fontFamily = MetropolisFamily,
            color = OverlayColors.darkText,
            lineHeight = 18.sp,
            modifier = Modifier.weight(1f),
        )
    }
}
