package com.snabbit.runner.shared.ui.components

import androidx.activity.compose.BackHandler
import androidx.compose.runtime.Composable

/** Android: bridge to Compose's [androidx.activity.compose.BackHandler] (host OnBackPressedDispatcher). */
@Composable
internal actual fun PlatformBackHandler(enabled: Boolean, onBack: () -> Unit) {
    BackHandler(enabled = enabled, onBack = onBack)
}
