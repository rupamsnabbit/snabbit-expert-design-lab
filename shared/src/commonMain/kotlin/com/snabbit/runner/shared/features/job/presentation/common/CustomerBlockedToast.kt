package com.snabbit.runner.shared.features.job.presentation.common

import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.snabbit.design.atoms.SnabbitToast
import com.snabbit.design.atoms.SnabbitToastVariant

/**
 * The post-block **"The customer is blocked"** confirmation toast (Figma: red `#DC2626`, top-anchored,
 * icon + Body-S/14-Semibold white text). Shown once when the runner blocks a customer from the
 * Completed stage — driven by the [com.snabbit.runner.shared.features.job.presentation.JobViewModel]
 * `blockedToast` one-shot, flipped into screen-local state by
 * [com.snabbit.runner.shared.features.job.presentation.JobScreen] and cleared here via [onShown] on
 * auto-dismiss so it can't re-appear on recomposition.
 *
 * A Compose toast (not a native host toast): it reuses the DS [SnabbitToast] Error variant — the
 * destructive-action red the Figma calls for — and sits top-aligned in the host root `Box`, matching
 * the sibling [JobActionToast] / DelayedCheckinToast surfaces. The Completed stage stays mounted until
 * "Ready for next job", so the toast displays fully.
 */
@Composable
fun BoxScope.CustomerBlockedToast(
    message: String,
    onShown: () -> Unit,
) {
    SnabbitToast(
        title = message,
        variant = SnabbitToastVariant.Error,
        durationMillis = TOAST_DURATION_MILLIS,
        onDismiss = onShown,
        modifier = Modifier
            .align(Alignment.TopCenter)
            .fillMaxWidth()
            .padding(16.dp),
    )
}

/** Auto-dismiss window — matches [JobActionToast]. */
private const val TOAST_DURATION_MILLIS = 4000L
