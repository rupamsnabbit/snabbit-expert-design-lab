package com.snabbit.runner.shared.features.job.presentation.newjob

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.features.job.presentation.JobStrings
import com.snabbit.runner.shared.features.job.presentation.JobUiState
import com.snabbit.runner.shared.features.job.presentation.common.JobActionToast

/**
 * Full-screen content of the New Job **overlay** window: the centred
 * [NewJobOverlayContent] card with the shared [JobActionToast] (accept/deny
 * feedback) floating at the top. Kept here (shared) so the overlay and the in-app
 * [JobScreen] render identical feedback.
 *
 * Applies [SnabbitTheme] for the whole surface (the toast is a sibling of the card,
 * so the theme must wrap both) — the native host can't, since the design system
 * isn't on its compile classpath. The dimmed scrim + window sizing are owned by the
 * native overlay host (`NewJobOverlayService`).
 */
@Composable
fun NewJobOverlaySurface(
    state: JobUiState.NewJob,
    strings: JobStrings,
    onAccept: () -> Unit,
    onDeny: () -> Unit,
    onErrorShown: () -> Unit,
    onSuccessShown: () -> Unit,
    modifier: Modifier = Modifier,
) {
    SnabbitTheme(darkTheme = false) {
        Box(
            modifier = modifier.fillMaxSize(),
            contentAlignment = Alignment.Center,
        ) {
            NewJobOverlayContent(
                state = state,
                strings = strings,
                onAccept = onAccept,
                onDeny = onDeny,
                modifier = Modifier.padding(horizontal = 16.dp),
            )
            JobActionToast(
                state = state,
                strings = strings,
                onErrorShown = onErrorShown,
                onSuccessShown = onSuccessShown,
            )
        }
    }
}
