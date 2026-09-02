package com.snabbit.runner.shared.core.camera.ui

import androidx.compose.runtime.Composable

/**
 * Intercepts the system back gesture when [enabled]. Used to lock the user
 * on a mandatory-capture flow (`allowBack = false`).
 *
 * expect/actual rather than a direct `BackHandler` import because the
 * Compose `BackHandler` lives in the Android-only `androidx.activity.compose`
 * package. Android delegates to it; iOS is a no-op for now (iOS uses an
 * edge-swipe back that is handled at the navigation layer when the iOS app
 * is built).
 */
@Composable
internal expect fun CameraBackHandler(enabled: Boolean, onBack: () -> Unit)
