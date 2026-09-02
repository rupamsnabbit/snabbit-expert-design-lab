package com.snabbit.runner.shared.features.shift.presentation.login
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.dp
import com.snabbit.design.atoms.SnabbitIcon
import com.snabbit.design.atoms.SnabbitIconName
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.atoms.SnabbitTextVariant
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.core.camera.internal.PlatformFileOps
import com.snabbit.runner.shared.features.shift.presentation.login.ShiftLoginStrings
import org.koin.compose.koinInject

/**
 * Figma 76-44493 — green-tinted overlay on the captured selfie with a check
 * badge + "Login successful". Renders the captured photo as the backdrop
 * (decoded via `loadDownsampledBitmap`) so the moment matches the live
 * camera frame the user just shot.
 */
@Composable
fun SuccessOverlay(
    capturedPath: String,
    strings: ShiftLoginStrings,
    modifier: Modifier = Modifier,
) {
    val fileOps = koinInject<PlatformFileOps>()
    val bitmap by produceState<androidx.compose.ui.graphics.ImageBitmap?>(
        initialValue = null,
        key1 = capturedPath,
    ) {
        value = fileOps.loadDownsampledBitmap(
            path = capturedPath,
            reqWidthPx = BACKDROP_MAX_PX,
            reqHeightPx = BACKDROP_MAX_PX,
            mirrorHorizontally = true,
        )
    }

    Box(modifier = modifier.fillMaxSize()) {
        bitmap?.let {
            Image(
                bitmap = it,
                contentDescription = null,
                modifier = Modifier.fillMaxSize(),
                contentScale = ContentScale.Crop,
            )
        }
        // Green wash matching Figma — moderate alpha so the photo remains
        // visible. Derived from the DS success color so the tint tracks the
        // token rather than a bespoke green.
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(SnabbitTheme.colors.iconSuccess.copy(alpha = 0.6f)),
        )
        Column(
            modifier = Modifier.fillMaxSize(),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Box(
                modifier = Modifier
                    .size(72.dp)
                    .clip(CircleShape)
                    .background(SnabbitTheme.colors.iconSuccess),
                contentAlignment = Alignment.Center,
            ) {
                SnabbitIcon(
                    name = SnabbitIconName.Check,
                    size = 40.dp,
                    color = SnabbitTheme.colors.iconInverse,
                )
            }
            Spacer(Modifier.height(SnabbitTheme.spacing.componentGapLg))
            SnabbitText(
                text = strings.successLabel,
                variant = SnabbitTextVariant.Heading3,
                color = SnabbitTheme.colors.textInverse,
            )
        }
    }
}

private const val BACKDROP_MAX_PX = 1080
