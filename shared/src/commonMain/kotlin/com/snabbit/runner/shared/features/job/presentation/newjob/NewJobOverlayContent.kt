package com.snabbit.runner.shared.features.job.presentation.newjob

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.dp
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.features.job.presentation.JobStrings
import com.snabbit.runner.shared.features.job.presentation.JobUiState
import com.snabbit.runner.shared.features.job.presentation.formatRupees
import com.snabbit.runner.shared.ui.components.SnabbitEarningsAccordion
import com.snabbit.runner.shared.ui.components.SnabbitJobState
import com.snabbit.runner.shared.ui.components.SnabbitJobStateStatus
import com.snabbit.runner.shared.features.job.presentation.common.AcceptFooter
import com.snabbit.runner.shared.features.job.presentation.common.rememberAcceptCountdown

/**
 * The `RUNNER_NEW_JOB` card rendered inside the **system overlay** (draw-over-other-apps)
 * when a job arrives while the app isn't foreground. Same three pieces as the in-app
 * [NewJobContent] — [SnabbitJobState] header, the earnings card, the accept/deny
 * [AcceptFooter] — but as a self-contained white card (no [com.snabbit.runner.shared.ui.SnabbitScreen]
 * Scaffold/top-nav/insets), matching Figma "Over the app" (node 14:10322).
 *
 * The earnings card is **non-collapsible** (`collapsible = false`) per product — no
 * expand/collapse chevron in the overlay. The surrounding scrim, centering, and window
 * sizing are owned by the native overlay host, not this composable.
 *
 * Applies [SnabbitTheme] itself (unlike the in-app path it skips
 * [com.snabbit.runner.shared.ui.SnabbitScreen], which normally provides it), so DS
 * tokens resolve. The native host (`:app`) can't — the design system isn't on its
 * compile classpath — so the theme provider must live here, on the shared side.
 * Light-only, matching `SnabbitScreen` (the Flutter host runs light theme).
 *
 * Stateless over [JobUiState.NewJob]; accept/deny are intent-sending lambdas, never the ViewModel.
 */
@Composable
fun NewJobOverlayContent(
    state: JobUiState.NewJob,
    strings: JobStrings,
    onAccept: () -> Unit,
    onDeny: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val model = state.model
    SnabbitTheme(darkTheme = false) {
        Column(
            modifier = modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(20.dp))
                .background(SnabbitTheme.colors.bgPrimary),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            // Header + earnings, inset inside the card padding (the footer below spans
            // the full card width with its own top border, matching the Figma layout).
            Column(
                modifier = Modifier.fillMaxWidth().padding(16.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                SnabbitJobState(
                    label = strings.newJobTitle,
                    status = SnabbitJobStateStatus.NewJob,
                )

                val payout = model.payout
                if (payout != null) {
                    SnabbitEarningsAccordion(
                        title = strings.youWillEarn,
                        amount = formatRupees(payout.totalEarning),
                        items = earningsItems(payout, strings),
                        collapsible = false,
                    )
                }
            }

            // The accept countdown ticks inside this footer's own recomposition scope (the
            // rememberAcceptCountdown read lives in OverlayAcceptFooter, not this outer Column), so the
            // per-second tick no longer recomposes the header + earnings accordion above.
            OverlayAcceptFooter(
                state = state,
                strings = strings,
                onAccept = onAccept,
                onDeny = onDeny,
            )
        }
    }
}

/**
 * The overlay's accept footer, ticking its own [rememberAcceptCountdown] internally so only this leaf
 * recomposes each second — the header + earnings accordion above don't. Unlike [JobScreen] (which
 * hoists the countdown so the deny sheet's fill stays in lockstep with the footer), the overlay has no
 * deny sheet, so nothing needs to share the ticker.
 */
@Composable
private fun OverlayAcceptFooter(
    state: JobUiState.NewJob,
    strings: JobStrings,
    onAccept: () -> Unit,
    onDeny: () -> Unit,
) {
    AcceptFooter(
        state = state,
        remaining = rememberAcceptCountdown(state),
        strings = strings,
        onAccept = onAccept,
        onDeny = onDeny,
    )
}
