package com.snabbit.runner.shared.core.camera.ui

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/**
 * Plays the captured video at [filePath] in the preview screen.
 *
 * Tap to play / pause; a play affordance shows while paused. Android uses the
 * platform `VideoView` (no extra dependency); iOS is stubbed until the iOS
 * camera path is built.
 */
@Composable
internal expect fun VideoPlayer(filePath: String, modifier: Modifier)
