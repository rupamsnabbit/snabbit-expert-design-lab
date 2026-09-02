package com.snabbit.runner.shared.ui.components

import androidx.compose.runtime.Composable

/** iOS has no hardware back button — nothing to intercept. */
@Composable
internal actual fun PlatformBackHandler(
    @Suppress("UNUSED_PARAMETER") enabled: Boolean,
    @Suppress("UNUSED_PARAMETER") onBack: () -> Unit,
) {
    // no-op
}
