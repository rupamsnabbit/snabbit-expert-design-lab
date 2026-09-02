package com.snabbit.runner.shared.core.camera.ui

import androidx.compose.runtime.Composable

/**
 * Invokes [onResumed] each time the host returns to the foreground (ON_RESUME).
 *
 * Used by [CameraScreen] to re-check the camera permission after the user comes
 * back from the OS app-settings screen (permanently-denied recovery) — so the
 * module doesn't depend on the host remembering to forward `onResume`.
 *
 * Android observes the Compose lifecycle; iOS is a no-op until the iOS camera
 * path is built (capture is stubbed this milestone).
 */
@Composable
internal expect fun OnAppResumed(onResumed: () -> Unit)
