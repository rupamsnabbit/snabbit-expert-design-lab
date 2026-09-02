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
import com.snabbit.runner.shared.features.job.presentation.JobStrings
import com.snabbit.runner.shared.features.job.presentation.JobUiState
import com.snabbit.runner.shared.features.job.presentation.resolve

/**
 * The shared accept/deny feedback toast — one place so the in-app [JobScreen] and
 * the over-other-apps overlay show identical feedback. Driven by the transient
 * [JobUiState.NewJob.errorMessage] / [JobUiState.NewJob.successMessage] one-shots
 * the [JobViewModel] sets on an action response:
 *  - **non-2xx → red** ([SnabbitToastVariant.Error]),
 *  - **2xx → green success** ([SnabbitToastVariant.Success]).
 *
 * Reuses the DS [SnabbitToast] (no hand-rolled UI). It auto-dismisses after
 * [TOAST_DURATION_MILLIS] and fires the matching `onShown` callback so the VM
 * clears the message and the toast doesn't re-appear on recomposition.
 *
 * Placed in the host's root `Box` (top-aligned). At most one message is set at a
 * time (the VM clears both at the start of each submit).
 *
 * TODO(ECPO-528 Phase 2): once the DS ships a blue toast variant, switch the
 * success toast from [SnabbitToastVariant.Success] (green) to the blue variant
 * (Figma 5-11546) — a one-line change here.
 */
@Composable
fun BoxScope.JobActionToast(
    state: JobUiState.NewJob,
    strings: JobStrings,
    onErrorShown: () -> Unit,
    onSuccessShown: () -> Unit,
) {
    val toastModifier = Modifier
        .align(Alignment.TopCenter)
        .fillMaxWidth()
        .padding(16.dp)

    val error = state.errorMessage
    val success = state.successMessage
    when {
        error != null -> SnabbitToast(
            title = strings.resolve(error),
            variant = SnabbitToastVariant.Error,
            durationMillis = TOAST_DURATION_MILLIS,
            onDismiss = onErrorShown,
            modifier = toastModifier,
        )
        success != null -> SnabbitToast(
            title = strings.resolve(success),
            variant = SnabbitToastVariant.Success,
            durationMillis = TOAST_DURATION_MILLIS,
            onDismiss = onSuccessShown,
            modifier = toastModifier,
        )
    }
}

/** Auto-dismiss window for the action feedback toast. */
private const val TOAST_DURATION_MILLIS = 4000L
