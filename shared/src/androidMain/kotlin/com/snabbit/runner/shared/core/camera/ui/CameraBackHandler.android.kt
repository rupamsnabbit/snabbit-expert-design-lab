package com.snabbit.runner.shared.core.camera.ui

import androidx.activity.compose.BackHandler
import androidx.compose.runtime.Composable

// `actual` for the commonMain `CameraBackHandler` expect (see its KDoc): the
// Compose `BackHandler` is Android-only, so commonMain can't call it directly
// and stay iOS-compilable. This is the thin Android delegate; iOS is a no-op.
@Composable
internal actual fun CameraBackHandler(enabled: Boolean, onBack: () -> Unit) {
    BackHandler(enabled = enabled, onBack = onBack)
}
