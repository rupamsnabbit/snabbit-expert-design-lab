package com.snabbit.runner.shared.core.camera.ui

import android.widget.VideoView
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import com.snabbit.design.atoms.SnabbitText
import com.snabbit.design.theme.SnabbitTheme

@Composable
internal actual fun VideoPlayer(filePath: String, modifier: Modifier) {
    var videoView by remember { mutableStateOf<VideoView?>(null) }
    var playing by remember { mutableStateOf(false) }

    Box(
        modifier = modifier.clickable(
            interactionSource = remember { MutableInteractionSource() },
            indication = null,
        ) {
            val view = videoView ?: return@clickable
            if (view.isPlaying) {
                view.pause()
                playing = false
            } else {
                view.start()
                playing = true
            }
        },
        contentAlignment = Alignment.Center,
    ) {
        AndroidView(
            modifier = Modifier.fillMaxSize(),
            factory = { ctx ->
                VideoView(ctx).apply {
                    setVideoPath(filePath)
                    // Show the first frame as a poster, paused.
                    setOnPreparedListener { mp ->
                        mp.isLooping = false
                        seekTo(1)
                    }
                    setOnCompletionListener { playing = false }
                    videoView = this
                }
            },
            // Release the underlying MediaPlayer when the preview leaves
            // composition (Retake / Submit / back) — avoids a leak.
            onRelease = { view -> view.stopPlayback() },
        )

        // Play affordance while paused (dark-scrim HUD circle — no DS component
        // for a video overlay, so it's a Box + SnabbitText on token colors).
        if (!playing) {
            @Suppress("MagicNumber")
            Box(
                modifier = Modifier
                    .size(64.dp)
                    .clip(CircleShape)
                    .background(SnabbitTheme.colors.bgInverse.copy(alpha = 0.4f)),
                contentAlignment = Alignment.Center,
            ) {
                SnabbitText(text = "▶", color = SnabbitTheme.colors.textInverse, fontSize = 28.sp)
            }
        }
    }
}
