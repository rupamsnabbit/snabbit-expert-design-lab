package com.snabbit.runner.shared.core.camera.ui

import androidx.compose.runtime.Composable

@Composable
internal actual fun OnAppResumed(onResumed: () -> Unit) {
    // No-op until the iOS camera path is built (iOS capture is stubbed this milestone).
}
