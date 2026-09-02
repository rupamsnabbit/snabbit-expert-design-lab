package com.snabbit.runner.shared.features.job.presentation.common

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.State
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import com.snabbit.design.atoms.SnabbitButtonStyle
import com.snabbit.design.theme.SnabbitColorsLight
import com.snabbit.runner.shared.features.job.data.JobSubmitAction
import com.snabbit.runner.shared.features.job.presentation.JobStrings
import com.snabbit.runner.shared.features.job.presentation.JobUiState
import com.snabbit.runner.shared.features.job.presentation.formatIsoClockTime
import com.snabbit.runner.shared.features.job.presentation.formatMmSs
import com.snabbit.runner.shared.ui.components.SnabbitActionFooter
import com.snabbit.runner.shared.ui.components.SnabbitActionFooterUrgentStyle
import kotlinx.coroutines.delay
import kotlin.time.TimeSource

/**
 * Ticks the New-Job accept countdown down locally, re-seeded from
 * [JobUiState.NewJob.acceptRemainingSeconds] each envelope (so the ViewModel needn't emit every
 * second). Recomputes from elapsed time each tick (not `remaining--`) so cumulative delay latency
 * can't make it lag wall-clock.
 *
 * Returns the live count as a [State] (not a bare `Int`), mirroring [rememberInProgressTimer]: the
 * per-second read is deferred to whoever reads `.value` (the footer / deny sheet leaf), so holding it
 * in [JobScreen]'s scope no longer recomposes the whole New-Job screen each second.
 *
 * Hoisted by [JobScreen] so the bottom-bar [AcceptFooter] and the deny/logout sheet share ONE
 * ticker: previously each took its own `markNow()` at composition, so the sheet's Accept fill jumped
 * backward when it opened over the still-ticking footer (ECPO issue #2). `NewJobOverlayContent`
 * hoists its own (it has no deny sheet).
 */
@Composable
internal fun rememberAcceptCountdown(state: JobUiState.NewJob): State<Int> {
    var remaining by remember(state.acceptRemainingSeconds, state.acceptTotalSeconds) {
        mutableStateOf(state.acceptRemainingSeconds)
    }
    LaunchedEffect(state.acceptRemainingSeconds, state.acceptTotalSeconds) {
        val seed = state.acceptRemainingSeconds
        val start = TimeSource.Monotonic.markNow()
        // 0 is terminal for the accept window (offer expired → job gone), so the loop exits there —
        // unlike the check-in / in-progress tickers, which deliberately count through 0. A later poll
        // re-seeding a *non-zero* value changes the key and restarts; re-seeding 0 intentionally won't.
        while (remaining > 0) {
            delay(1000)
            remaining = (seed - start.elapsedNow().inWholeSeconds).toInt().coerceAtLeast(0)
        }
    }
    // Wrapped as [derivedStateOf] so callers hold a stable State ref and the ticking read is deferred
    // to whoever reads `.value` — same shape as [rememberInProgressTimer].
    return remember(state) { derivedStateOf { remaining } }
}

/**
 * Accept countdown footer — shared by [JobScreen]'s bottom bar and the `NewJobOverlayContent`
 * card so the urgent threshold and deny-when-deniable logic live in one place. The live [remaining]
 * countdown [State] is ticked by [rememberAcceptCountdown] and passed in; its `.value` is read here,
 * in the footer's own scope, so only the footer — not the whole screen — recomposes each second. The
 * footer and the deny sheet read the same hoisted State, so they stay in lockstep. Deny shows only
 * when the job is deniable.
 */
@Composable
internal fun AcceptFooter(
    state: JobUiState.NewJob,
    remaining: State<Int>?,
    strings: JobStrings,
    onAccept: () -> Unit,
    onDeny: () -> Unit,
) {
    // Read the ticking countdown here (the footer's leaf scope), so [JobScreen] just holds the hoisted
    // State — mirrors CompleteJobFooter reading `inProgressTimer?.value` rather than the screen doing so.
    // Falls back to the envelope seed if the hoisted ticker is absent (defensive; it's always present in
    // the new-job stage — the overlay passes a non-null one directly).
    val remainingSeconds = remaining?.value ?: state.acceptRemainingSeconds
    val total = state.acceptTotalSeconds.coerceAtLeast(1)
    val progress = (1f - remainingSeconds.toFloat() / total).coerceIn(0f, 1f)
    // Footer flips to its urgent (red, blinking) state for the final third of the
    // accept window — mirrors the old new_job_assigned.dart red cutoff
    // (remaining < timerDuration / 3). Binary normal/urgent (product call: no yellow
    // tier, button stays green); threshold hardcoded for now.
    val urgent = remainingSeconds < total / 3

    SnabbitActionFooter(
        caption = strings.acceptIn,
        time = formatMmSs(remainingSeconds),
        primaryLabel = strings.acceptJob,
        onPrimaryClick = onAccept,
        buttonType = SnabbitButtonStyle.Success,
        progress = progress,
        urgent = urgent,
        // New-job urgency is a red BLINK — the whole footer throbs — NOT the check-in flows'
        // directional countdown wash (the default). The blink ignores urgentFillProgress.
        urgentStyle = SnabbitActionFooterUrgentStyle.Blink,
        secondaryLabel = if (state.model.isDeniable) strings.deny else null,
        onSecondaryClick = onDeny,
        // Deny reads in red-600 (Figma), matching the deny/logout sheet's CTA.
        secondaryContentColor = SnabbitColorsLight.red600,
        // (there is no red-600 semantic token; the DS palette object is the sanctioned source)
        // While an accept/deny call is in flight: spinner on the button the runner actually pressed
        // (Accept vs Deny), with BOTH buttons' taps blocked. Previously the single `isSubmitting` flag
        // spun the primary (Accept) even for a deny — the wrong button.
        enabled = state.submittingAction == null,
        loading = state.submittingAction == JobSubmitAction.Accept,
        secondaryLoading = state.submittingAction == JobSubmitAction.Deny,
    )
}

/**
 * Check-in footer — the sticky bottom bar on the [JobUiState.AwaitingCheckIn] screen. A
 * [SnabbitActionFooter] with a check-in-bonus countdown over a pink "Check In" CTA that
 * opens the OTP sheet ([onCheckIn]).
 *
 * The metric counts down to the bonus deadline (green "CHECK IN BY 7:45 PM" / "1:23"),
 * then flips to the urgent red "RUNNING LATE" / "-01:23" once it passes — the same
 * local-tick pattern as [AcceptFooter], re-seeded from the envelope each time. When the
 * job carries no check-in bonus (no deadline), the metric is omitted and only the CTA shows.
 */
@Composable
internal fun CheckInFooter(
    state: JobUiState.AwaitingCheckIn,
    strings: JobStrings,
    onCheckIn: () -> Unit,
) {
    // Single source of truth: the countdown exists iff the ViewModel produced a seed. Gate the whole
    // metric on this — NOT on re-derived raw envelope fields, which drift from the seed (the seed now
    // tracks start_time while the old gate read checkin_promise/check_in_time).
    val seed = state.checkInRemainingSeconds
    val hasCountdown = seed != null
    // "CHECK IN BY" label prefers the bonus deadline time, falling back to the countdown's.
    val labelTime = formatIsoClockTime(state.payout?.checkInTimeIso ?: state.checkInDeadlineIso)
    var remaining by remember(seed) { mutableStateOf(seed ?: 0) }
    LaunchedEffect(seed) {
        // Tick down to the deadline, then keep going negative for the "running late" count-up.
        // Recompute from elapsed time (not `remaining--`) so it doesn't drift behind wall-clock;
        // re-seeds from the envelope each poll. No seed → no ticking.
        val start = seed ?: return@LaunchedEffect
        val markedAt = TimeSource.Monotonic.markNow()
        while (true) {
            delay(1000)
            remaining = (start - markedAt.elapsedNow().inWholeSeconds).toInt()
        }
    }

    val late = hasCountdown && remaining <= 0
    val total = state.checkInTotalSeconds
    val progress = if (hasCountdown && total > 0) {
        (1f - remaining.toFloat() / total).coerceIn(0f, 1f)
    } else {
        0f
    }
    val caption = when {
        !hasCountdown -> ""
        late -> strings.runningLate
        else -> strings.checkInByCaps.replace("{time}", labelTime ?: "").trim()
    }
    val time = when {
        !hasCountdown -> ""
        late -> "-${formatMmSs(-remaining)}"
        else -> formatMmSs(remaining)
    }

    SnabbitActionFooter(
        caption = caption,
        time = time,
        primaryLabel = strings.checkIn,
        onPrimaryClick = onCheckIn,
        buttonType = SnabbitButtonStyle.Primary,
        urgent = late,
        progress = progress,
        // The wash only shows when `late` (urgent = late), i.e. already past the deadline —
        // the full overrun state. Deriving the fill from `progress` collapses it to an
        // invisible wash when the countdown total is unparseable (total <= 0 forces
        // progress to 0), so pin the overrun to a full wash directly.
        urgentFillProgress = 1f,
        // The CTA only opens the check-in sheet; the sheet owns the in-flight state (its Start Job
        // button spins), and it covers this footer while a call is in flight — so it stays enabled.
        enabled = true,
        loading = false,
    )
}
