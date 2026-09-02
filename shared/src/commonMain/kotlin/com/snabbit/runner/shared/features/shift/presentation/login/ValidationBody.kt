package com.snabbit.runner.shared.features.shift.presentation.login
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.snabbit.design.atoms.SnabbitButton
import com.snabbit.design.atoms.SnabbitButtonSize
import com.snabbit.design.atoms.SnabbitButtonStyle
import com.snabbit.design.atoms.SnabbitIcon
import com.snabbit.design.atoms.SnabbitIconName
import com.snabbit.design.atoms.SnabbitRemoteImage
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.atoms.SnabbitTextVariant
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.features.shift.core.domain.model.SelfieValidationCode

/** Same correct-uniform reference the IntroSheet uses for its "do" example. */
private const val SELFIE_GOOD_IMAGE_URL =
    "https://assets-expert.snabbit.com/shift-login/selfie_do.png"

/**
 * The rejected-capture VIEW for [ShiftLoginPhase.Validation] — the frozen selfie,
 * red-bordered to read as "rejected". This stays as the screen body (under the
 * "Take a selfie" top nav) exactly as the capture view was; the reason line(s),
 * the current-vs-expected comparison, and the Retake CTA ride on top in
 * [ValidationSheet] (a `SnabbitBottomSheet`), matching Figma `Snabbit Cancelled.png`.
 *
 * [bitmap] is decoded by the caller (front-camera → mirrored), the same source the
 * Uploading/Success bodies use, so it is shared with the sheet's ❌ comparison tile.
 */
@Composable
fun ValidationCaptureView(bitmap: ImageBitmap?, modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .fillMaxSize()
            .clip(RoundedCornerShape(SnabbitTheme.borderRadius.lg))
            .border(
                width = 2.dp,
                color = SnabbitTheme.colors.textError,
                shape = RoundedCornerShape(SnabbitTheme.borderRadius.lg),
            ),
        contentAlignment = Alignment.Center,
    ) {
        bitmap?.let {
            Image(
                bitmap = it,
                contentDescription = null,
                modifier = Modifier.fillMaxSize(),
                contentScale = ContentScale.Crop,
            )
        }
    }
}

/**
 * Bottom-sheet content for a rejected selfie: the reason line(s), the
 * current (❌, [capturedBitmap]) vs expected (✓, correct-uniform) comparison, and
 * the Retake CTA. Presented in a `SnabbitBottomSheet` over [ValidationCaptureView]
 * — the capture view underneath is left untouched.
 */
@Composable
fun ValidationSheet(
    codes: List<SelfieValidationCode>,
    capturedBitmap: ImageBitmap?,
    strings: ShiftLoginStrings,
    onRetake: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(SnabbitTheme.spacing.componentPaddingMd),
        verticalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.componentGapLg),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        // Reason line(s) — the primary rejection reason reads as the headline.
        codes.forEach { code ->
            SnabbitText(
                text = strings.validationLine(code),
                variant = SnabbitTextVariant.Heading3,
                color = SnabbitTheme.colors.textPrimary,
                textAlign = TextAlign.Center,
            )
        }

        // current (your photo, ❌) vs expected (correct uniform, ✓)
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(SnabbitTheme.spacing.componentGapMd),
        ) {
            ComparisonTile(modifier = Modifier.weight(1f), correct = false, bitmap = capturedBitmap)
            ComparisonTile(modifier = Modifier.weight(1f), correct = true, imageUrl = SELFIE_GOOD_IMAGE_URL)
        }

        SnabbitButton(
            text = strings.validationRetakeCta,
            onClick = onRetake,
            style = SnabbitButtonStyle.Primary,
            size = SnabbitButtonSize.L,
            fullWidth = true,
            modifier = Modifier.fillMaxWidth(),
        )
    }
}

/**
 * One square tile of the comparison. Renders either the local captured [bitmap]
 * or a remote [imageUrl], with a corner badge — green ✓ ([correct]) or red ✕.
 */
@Composable
private fun ComparisonTile(
    correct: Boolean,
    modifier: Modifier = Modifier,
    bitmap: ImageBitmap? = null,
    imageUrl: String? = null,
) {
    Box(modifier = modifier.aspectRatio(1f), contentAlignment = Alignment.TopEnd) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .clip(RoundedCornerShape(SnabbitTheme.borderRadius.md)),
        ) {
            when {
                bitmap != null -> Image(
                    bitmap = bitmap,
                    contentDescription = null,
                    modifier = Modifier.fillMaxSize(),
                    contentScale = ContentScale.Crop,
                )
                imageUrl != null -> SnabbitRemoteImage(
                    model = imageUrl,
                    contentDescription = null,
                    modifier = Modifier.fillMaxSize(),
                    contentScale = ContentScale.Crop,
                )
            }
        }
        Badge(correct = correct)
    }
}

/**
 * Corner status badge. The green ✓ reuses the IntroSheet convention (the vendored
 * `CheckCircle` glyph on a white disc); the red ✕ is a filled error disc.
 */
@Composable
private fun BoxScope.Badge(correct: Boolean) {
    Box(
        modifier = Modifier
            .align(Alignment.TopEnd)
            .size(32.dp)
            .clip(CircleShape)
            .background(if (correct) SnabbitTheme.colors.bgPrimary else SnabbitTheme.colors.iconError),
        contentAlignment = Alignment.Center,
    ) {
        if (correct) {
            SnabbitIcon(
                name = SnabbitIconName.CheckCircle,
                size = 32.dp,
                color = SnabbitTheme.colors.textSuccess,
            )
        } else {
            SnabbitIcon(
                name = SnabbitIconName.Close,
                size = 18.dp,
                color = SnabbitTheme.colors.iconInverse,
            )
        }
    }
}
