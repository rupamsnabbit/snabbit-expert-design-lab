package com.snabbit.runner.shared.core.camera.ui

import com.snabbit.runner.shared.core.camera.CameraResult
import com.snabbit.runner.shared.core.camera.CapturedMedia
import com.snabbit.runner.shared.core.camera.exceedsSizeCap
import com.snabbit.runner.shared.core.camera.internal.PlatformFileOps
import com.snabbit.runner.shared.core.camera.sizeCapBytes

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
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
import com.snabbit.design.atoms.SnabbitStatusBanner
import com.snabbit.design.atoms.SnabbitStatusBannerVariant
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.atoms.SnabbitTextVariant
import com.snabbit.design.atoms.textColor
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.core.designsystem.SnabbitScreen
import org.koin.compose.koinInject

/**
 * The built-in preview screen ([PreviewMode.Default]). Shows the captured
 * [media] in a rounded container with **Retake** / **Submit** actions.
 *
 * - Photo → downsampled [ImageBitmap], crop-to-fill (tri-state: loading /
 *   loaded / failed).
 * - Video → tap-to-play [VideoPlayer].
 *
 * **Edge cases handled:**
 * - Over-cap media → a [SnabbitStatusBanner] + Submit disabled (can't submit a
 *   file the downstream WebView would 404).
 * - Decode failure / missing file → error message, Retake still available.
 *
 * Identical for front and back camera. Back press = Retake. Chrome (theme,
 * top nav, insets) comes from [SnabbitScreen]; visible UI uses DS components.
 */
@Composable
internal fun MediaPreviewScreen(
    media: CapturedMedia,
    strings: PreviewStrings,
    onRetake: () -> Unit,
    onSubmit: () -> Unit,
    modifier: Modifier = Modifier,
    mirror: Boolean = false,
) {
    val oversize = media.exceedsSizeCap()

    SnabbitScreen(
        modifier = modifier,
        title = strings.title,
        subtitle = strings.subtitle,
        onNavigateUp = onRetake,
        navigationIcon = { CameraBackButton(onClick = onRetake) },
        bottomBar = {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 16.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                SnabbitButton(
                    text = strings.retakeButton,
                    onClick = onRetake,
                    style = SnabbitButtonStyle.NeutralStroke,
                    size = SnabbitButtonSize.L,
                    fullWidth = true,
                    modifier = Modifier.weight(1f),
                )
                SnabbitButton(
                    text = strings.submitButton,
                    onClick = onSubmit,
                    style = SnabbitButtonStyle.Primary,
                    size = SnabbitButtonSize.L,
                    // Block Submit for over-cap media — retake is the only way out.
                    enabled = !oversize,
                    fullWidth = true,
                    modifier = Modifier.weight(1f),
                )
            }
        },
    ) { padding ->
        Column(modifier = Modifier.fillMaxSize().padding(padding)) {
            // ── Media container ──────────────────────────────────
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f)
                    .padding(horizontal = 20.dp, vertical = 16.dp)
                    .clip(RoundedCornerShape(24.dp))
                    .background(SnabbitTheme.colors.bgInverse),
                contentAlignment = Alignment.Center,
            ) {
                when (media) {
                    is CameraResult.Photo -> PhotoContent(media, mirror)
                    is CameraResult.Video -> VideoContent(media)
                }
            }

            // ── Over-cap warning ─────────────────────────────────
            if (oversize) {
                SizeWarningBanner(
                    media = media,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 8.dp),
                )
            }
        }
    }
}

// ── Photo (tri-state load) ───────────────────────────────────────

private sealed interface PhotoLoad {
    data object Loading : PhotoLoad
    data class Loaded(val bitmap: ImageBitmap) : PhotoLoad
    data object Failed : PhotoLoad
}

@Composable
private fun PhotoContent(photo: CameraResult.Photo, mirror: Boolean) {
    val fileOps = koinInject<PlatformFileOps>()
    BoxWithConstraints(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center,
    ) {
        val reqW = constraints.maxWidth.coerceAtLeast(1)
        val reqH = constraints.maxHeight.coerceAtLeast(1)

        // Decode at container resolution (OOM-safe); the seam threads the decode
        // off the main thread. mirror un-mirrors front-camera selfies (sensor
        // mirror, no EXIF flag).
        val load by produceState<PhotoLoad>(
            initialValue = PhotoLoad.Loading,
            key1 = photo.filePath,
            key2 = reqW,
            key3 = mirror,
        ) {
            val bmp = fileOps.loadDownsampledBitmap(photo.filePath, reqW, reqH, mirror)
            value = if (bmp != null) PhotoLoad.Loaded(bmp) else PhotoLoad.Failed
        }

        when (val state = load) {
            is PhotoLoad.Loading ->
                CircularProgressIndicator(color = SnabbitTheme.colors.textInverse)
            is PhotoLoad.Loaded -> Image(
                bitmap = state.bitmap,
                contentDescription = "Captured photo",
                modifier = Modifier.fillMaxSize(),
                contentScale = ContentScale.Crop,
            )
            is PhotoLoad.Failed -> PreviewMessage("Couldn't load the photo.\nPlease retake.")
        }
    }
}

// ── Video (tap-to-play player) ───────────────────────────────────

@Composable
private fun VideoContent(video: CameraResult.Video) {
    VideoPlayer(filePath = video.filePath, modifier = Modifier.fillMaxSize())
}

// ── Pieces ───────────────────────────────────────────────────────

/** White-on-black message shown inside the (black) media container. */
@Composable
private fun PreviewMessage(text: String) {
    SnabbitText(
        text = text,
        variant = SnabbitTextVariant.BodyMd,
        color = SnabbitTheme.colors.textInverse,
        textAlign = TextAlign.Center,
        modifier = Modifier.padding(24.dp),
    )
}

@Composable
private fun SizeWarningBanner(media: CapturedMedia, modifier: Modifier = Modifier) {
    val sizeMb = media.sizeBytes.toCeilMb()
    val capMb = media.sizeCapBytes().toCeilMb()
    SnabbitStatusBanner(
        modifier = modifier,
        variant = SnabbitStatusBannerVariant.Error,
    ) {
        SnabbitText(
            text = "Too large to submit ($sizeMb MB, max $capMb MB). Please retake.",
            variant = SnabbitTextVariant.Caption,
            color = SnabbitStatusBannerVariant.Error.textColor,
        )
    }
}

/** Bytes → whole megabytes, rounded up (so 10.1 MB shows as 11, not 10). */
private fun Long.toCeilMb(): Long = (this + BYTES_PER_MB - 1) / BYTES_PER_MB

private const val BYTES_PER_MB = 1024L * 1024L
