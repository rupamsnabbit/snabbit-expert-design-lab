package com.snabbit.runner.shared.core.camera.ui

import androidx.compose.runtime.Composable

@Composable
internal actual fun CameraBackHandler(enabled: Boolean, onBack: () -> Unit) {
    // No-op on iOS. Back is an edge-swipe handled by the navigation layer;
    // mandatory-capture lock will be wired when the iOS app is built.
}
