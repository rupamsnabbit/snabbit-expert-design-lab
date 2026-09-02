package com.snabbit.runner.shared.features.job.delayedcheckin.presentation

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.features.job.delayedcheckin.domain.model.ReachBy
import com.snabbit.runner.shared.ui.components.SnabbitActionFooter
import org.jetbrains.compose.ui.tooling.preview.Preview

/**
 * DelayedCheckinFooter — the sticky bottom bar while the delayed check-in penalty flow is
 * active: the always-urgent "RUNNING LATE" timer banner (blinking red wash) over the
 * "Check In" CTA and a secondary support CTA.
 *
 * Thin over [SnabbitActionFooter]'s existing `urgent` ("Red state") presentation — the
 * blink animation, metric layout, and button stack live there; this adds the delayed
 * check-in semantics:
 *
 * - the caption is **always** [DelayedCheckinStrings.runningLate] (the penalty flow is by
 *   definition late — unlike `CheckInFooter`, which flips between "CHECK IN BY" and late),
 * - the timer renders a **non-negative** `mm:ss` (`"01:23"` counting down, then held at
 *   `"00:00"` at/after the deadline — never a negative overrun), zero-padded via
 *   [ReachBy.display]. Overrun is still reflected by the full wash + the secondary-CTA
 *   swap the host drives from `isOverrun` (which stays on the signed state value),
 * - the secondary CTA swaps label + action with the penalty state ("Help" ↔ "Call
 *   Partner Support" — pass [DelayedCheckinStrings.help] / [callPartnerSupport]); *when*
 *   it swaps is the ViewModel's decision, not this widget's.
 *
 * Stateless: [remainingSeconds] is a plain signed value — the host ticks it (the
 * ViewModel collects `ReachByTicker`, per its termination contract) and this only
 * renders. The primary CTA stays enabled even mid-flight, like `CheckInFooter`: it only
 * opens the check-in sheet, which owns its own in-flight state.
 */
@Composable
fun DelayedCheckinFooter(
    remainingSeconds: Int,
    totalSeconds: Int,
    secondaryLabel: String,
    strings: DelayedCheckinStrings,
    onCheckIn: () -> Unit,
    onSecondaryClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    // The wash fills 0 → 1 over the countdown window (elapsed fraction); overrun
    // (negative remaining) clamps to a full bar. Malformed totals default full.
    val fillProgress = if (totalSeconds > 0) {
        (1f - remainingSeconds.toFloat() / totalSeconds).coerceIn(0f, 1f)
    } else {
        1f
    }
    SnabbitActionFooter(
        caption = strings.runningLate,
        // Non-negative timer: past the deadline (and during the gap between penalty
        // iterations, when the old deadline has expired but the next payload hasn't
        // re-anchored yet) the countdown holds at "00:00" instead of ticking negative.
        time = ReachBy(remainingSeconds.coerceAtLeast(0)).display(),
        primaryLabel = strings.checkIn,
        onPrimaryClick = onCheckIn,
        modifier = modifier,
        urgent = true,
        urgentFillProgress = fillProgress,
        secondaryLabel = secondaryLabel,
        onSecondaryClick = onSecondaryClick,
    )
}

/* ── Previews ────────────────────────────────────────────────────────── */

@Preview
@Composable
private fun PreviewDelayedCheckinFooterCountingDown() {
    SnabbitTheme {
        DelayedCheckinFooter(
            remainingSeconds = 83,
            totalSeconds = 300,
            secondaryLabel = DelayedCheckinStrings().help,
            strings = DelayedCheckinStrings(),
            onCheckIn = {},
            onSecondaryClick = {},
        )
    }
}

@Preview
@Composable
private fun PreviewDelayedCheckinFooterOverrun() {
    SnabbitTheme {
        // Overrun: signed state is negative but the timer holds at "00:00"; the
        // secondary CTA swaps to "Call Partner Support" (host-driven by isOverrun).
        DelayedCheckinFooter(
            remainingSeconds = -83,
            totalSeconds = 300,
            secondaryLabel = DelayedCheckinStrings().callPartnerSupport,
            strings = DelayedCheckinStrings(),
            onCheckIn = {},
            onSecondaryClick = {},
        )
    }
}
