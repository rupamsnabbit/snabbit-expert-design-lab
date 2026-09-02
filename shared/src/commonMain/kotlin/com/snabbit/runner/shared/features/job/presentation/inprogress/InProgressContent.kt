package com.snabbit.runner.shared.features.job.presentation.inprogress

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.State
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import org.jetbrains.compose.ui.tooling.preview.Preview
import com.snabbit.design.atoms.SnabbitButton
import com.snabbit.design.atoms.SnabbitButtonLoadingPosition
import com.snabbit.design.atoms.SnabbitButtonSize
import com.snabbit.design.atoms.SnabbitButtonStyle
import com.snabbit.design.atoms.SnabbitTooltip
import com.snabbit.design.atoms.SnabbitTooltipArrowPosition
import com.snabbit.design.atoms.SnabbitTooltipVariant
import com.snabbit.design.theme.SnabbitColorsLight
import com.snabbit.design.theme.SnabbitTheme
import com.snabbit.runner.shared.features.job.presentation.contact.CustomerContactHandler
import com.snabbit.runner.shared.features.job.presentation.contact.NoOpCustomerContactHandler
import com.snabbit.runner.shared.features.job.JobAnalytics
import com.snabbit.runner.shared.features.job.domain.model.JobPreference
import com.snabbit.runner.shared.features.job.presentation.JobStrings
import com.snabbit.runner.shared.features.job.presentation.JobUiState
import com.snabbit.runner.shared.features.job.presentation.rememberJobStrings
import com.snabbit.runner.shared.features.job.presentation.formatMmSs
import com.snabbit.runner.shared.ui.components.SnabbitJobState
import com.snabbit.runner.shared.ui.components.SnabbitJobStateStatus
import com.snabbit.runner.shared.ui.icons.AppIcons
import kotlinx.coroutines.delay
import kotlin.time.TimeSource

/**
 * `RUNNER_JOB_IN_PROGRESS` body — the job-in-progress screen the runner sees while working. Composes
 * existing app/DS components matching Figma "Shift — Job Lifecycle DS" (nodes 6:8405 job-start /
 * 9:8300 past-half / 10:9397 nearing-end):
 *
 *  - [SnabbitJobState] "Job In Progress" header,
 *  - [InProgressTimerPill] countdown pill (Green → Yellow → Red as the timer runs down),
 *  - an optional [SnabbitTooltip] beneath the pill (auto-checkout / time-up / next-job-ready),
 *  - [JobDetailsCard] (customer, timing, duration + chat/call),
 *  - [CustomerPreferencesCard] (spice/oil levels …),
 *
 * over a soft **green → yellow → red** top glow that transitions with the timer state. The
 * "Complete Job" CTA lives in the screen's bottom bar ([CompleteJobFooter]); both read the same
 * [timer] so the pill, gradient, callout and CTA-enabled state stay in lock-step. All state-driven
 * values come from [rememberInProgressTimer].
 *
 * @param contact handles the customer call (masked, dialer fallback) + chat (placeholder); the host
 *   passes a real handler.
 */
@Composable
internal fun InProgressContent(
    state: JobUiState.InProgress,
    timer: State<InProgressTimerState>,
    strings: JobStrings,
    contentPadding: PaddingValues,
    modifier: Modifier = Modifier,
    contact: CustomerContactHandler = NoOpCustomerContactHandler,
    // Job-lifecycle instrumentation (nullable so previews / un-hosted renders stay DI-free).
    analytics: JobAnalytics? = null,
    // Snabbit Kavach block (host-provided) appended inside the details card — null hides it (spec 2).
    kavachCard: (@Composable () -> Unit)? = null,
    // Tiering job nudge ("Do a perfect job") — 6dp between the job-info and customer-preferences.
    jobTieringNudge: (@Composable () -> Unit)? = null,
) {
    // Two-tier top glow per the Figma "Job / in progress" states (nodes 2877:52696 green /
    // 2877:52715 yellow / 2877:52736 red): a stronger INNER tint at the very top over a lighter
    // OUTER halo, fading into the gray-50 base. Figma renders it as two 50px-blurred radial blobs
    // sitting above the frame; approximated here as a vertical 3-stop gradient (a runtime blur isn't
    // cheap cross-platform), fading into the screen bg. Palette refs — the exact per-tier tints have
    // no single semantic token. Derived off the colour tier only (3 transitions), so this scope
    // recomposes on a colour change — not every second — confining the per-second tick to
    // [InProgressTimerSection] below.
    val color by remember(timer) { derivedStateOf { timer.value.color } }
    val innerTarget = when (color) {
        InProgressColor.Green -> SnabbitColorsLight.green300
        InProgressColor.Yellow -> SnabbitColorsLight.yellow200
        InProgressColor.Red -> SnabbitColorsLight.red400
    }
    val outerTarget = when (color) {
        InProgressColor.Green -> SnabbitColorsLight.green100
        InProgressColor.Yellow -> SnabbitColorsLight.yellow100
        InProgressColor.Red -> SnabbitColorsLight.red200
    }
    // Tween each tier across the green→yellow→red transitions (matching the old single-glow tween).
    val inner by animateColorAsState(
        targetValue = innerTarget,
        animationSpec = tween(durationMillis = 600),
        label = "jobProgressGlowInner",
    )
    val outer by animateColorAsState(
        targetValue = outerTarget,
        animationSpec = tween(durationMillis = 600),
        label = "jobProgressGlowOuter",
    )
    val base = SnabbitColorsLight.gray50
    // Memoized so the per-second countdown recomposition doesn't re-allocate the Brush each tick —
    // it's only rebuilt when a tweened tint (or the base) actually changes.
    val glowBrush = remember(inner, outer, base) {
        Brush.verticalGradient(0f to inner, 0.12f to outer, 0.4f to base)
    }

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(glowBrush),
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(contentPadding)
                .padding(horizontal = 20.dp, vertical = 20.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(24.dp),
        ) {
            // ── Job-state header + countdown pill + status callout — the only per-second section ──
            InProgressTimerSection(timer = timer, strings = strings)

            // Job-info + (optional) tiering nudge + customer preferences grouped so the nudge sits
            // 6dp between the two sections; without a nudge they keep the outer 24dp rhythm.
            Column(
                modifier = Modifier.fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(if (jobTieringNudge != null) 6.dp else 24.dp),
            ) {
                // ── Customer + job details (chat/call) ──
                JobDetailsCard(
                    details = JobDetails(
                        customerName = state.customerName?.takeIf { it.isNotBlank() } ?: strings.customerFallback,
                        jobTiming = state.jobTiming,
                        duration = state.durationLabel,
                        extraDuration = state.extraDurationLabel,
                        customerPhone = state.customerPhone,
                    ),
                    contact = contact,
                    analytics = analytics,
                    jobTimingLabel = strings.jobTimingLabel,
                    durationLabel = strings.durationLabel,
                    kavach = kavachCard,
                )

                // "Do a perfect job" — between job-info and customer preferences (6dp each side).
                jobTieringNudge?.invoke()

                // ── Customer preferences (renders nothing when empty) ──
                CustomerPreferencesCard(
                    title = strings.customerPreferencesTitle,
                    items = state.preferences.map { pref ->
                        CustomerPreferenceItem(
                            label = pref.label,
                            value = pref.value,
                            icon = customerPreferenceIcon(pref.key),
                        )
                    },
                )
            }
        }
    }
}

/**
 * The per-second-ticking header — job-state chip, countdown pill and status callout. Split out so
 * this is the ONLY scope that reads [timer]'s value (and thus recomposes each second); the sibling
 * details/preferences cards read `state` alone and skip the tick.
 */
@Composable
private fun InProgressTimerSection(
    timer: State<InProgressTimerState>,
    strings: JobStrings,
) {
    val t = timer.value
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        SnabbitJobState(
            label = strings.jobInProgressTitle,
            status = SnabbitJobStateStatus.InProgress,
        )
        InProgressTimerPill(
            time = t.timeText,
            color = t.color,
            label = t.pillLabel,
            progress = t.progress,
        )
        t.calloutText?.let { text ->
            val calloutVariant = if (t.calloutIsError) {
                SnabbitTooltipVariant.Error
            } else {
                SnabbitTooltipVariant.Success
            }
            val calloutIcon = t.calloutIcon
            if (calloutIcon != null) {
                SnabbitTooltip(
                    text = text,
                    variant = calloutVariant,
                    arrowPosition = t.calloutArrow,
                    // Baked-colour glyph → foundation Image (a single-tint SnabbitIcon would flatten it).
                    icon = {
                        Image(
                            imageVector = calloutIcon,
                            contentDescription = null,
                            modifier = Modifier.size(16.dp),
                        )
                    },
                )
            } else {
                SnabbitTooltip(
                    text = text,
                    variant = calloutVariant,
                    arrowPosition = t.calloutArrow,
                )
            }
        }
    }
}

/**
 * The sticky "Complete Job" footer for the in-progress screen — a full-width primary CTA over a
 * white bar with a gray-100 top hairline (matching the accept / check-in footers). [enabled] is
 * driven by the timer (disabled until the job nears its end); the disabled fill is the DS pink-200.
 */
@Composable
internal fun CompleteJobFooter(
    label: String,
    enabled: Boolean,
    onComplete: () -> Unit,
    loading: Boolean = false,
) {
    Column(modifier = Modifier.fillMaxWidth().background(SnabbitTheme.colors.bgPrimary)) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(1.5.dp)
                .background(SnabbitTheme.colors.borderSubtle),
        )
        Box(modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 16.dp)) {
            SnabbitButton(
                text = label,
                onClick = onComplete,
                style = SnabbitButtonStyle.Primary,
                size = SnabbitButtonSize.L,
                fullWidth = true,
                // Disabled while the action is in flight so a second tap can't double-submit; the
                // leading spinner sits left of the label (matching the checkout / deny-sheet CTAs).
                enabled = enabled && !loading,
                loading = loading,
                loadingPosition = SnabbitButtonLoadingPosition.Leading,
            )
        }
    }
}

/**
 * Seeds the countdown from [JobUiState.InProgress.remainingSeconds] and ticks it locally each second
 * (like [AcceptFooter] / [CheckInFooter], so the ViewModel needn't emit per-second), deriving the
 * pill colour, time text, progress, callout, and Complete-enabled state via [deriveInProgressTimer].
 */
@Composable
internal fun rememberInProgressTimer(
    state: JobUiState.InProgress,
    strings: JobStrings,
): State<InProgressTimerState> {
    var remaining by remember(state.remainingSeconds, state.totalSeconds) {
        mutableStateOf(state.remainingSeconds)
    }
    LaunchedEffect(state.remainingSeconds, state.totalSeconds) {
        // Keep counting through zero — the auto-checkout window lives past end-time. Recompute from
        // elapsed time each tick (not `remaining--`) so cumulative delay latency doesn't make the
        // countdown lag wall-clock; re-seeds from the envelope each poll.
        val seed = state.remainingSeconds
        val start = TimeSource.Monotonic.markNow()
        while (true) {
            delay(1000)
            remaining = (seed - start.elapsedNow().inWholeSeconds).toInt()
        }
    }
    // Wrapped as [derivedStateOf] so callers hold a stable State ref: the ticking read is deferred to
    // whoever reads `.value` (the pill/footer), instead of recomposing the caller's scope each second.
    return remember(state, strings) { derivedStateOf { deriveInProgressTimer(remaining, state, strings) } }
}

/**
 * Maps the ticking [remaining] seconds to the render state, mirroring `on_the_job.dart`'s
 * `timerPeriodicProcess` thresholds:
 *  - `> checkoutBeforeMins·60` → **green**, Complete Job disabled;
 *  - `≤ checkoutBeforeMins·60` (and `> 60`) → **yellow**, Complete Job enabled;
 *  - `≤ 60` (or past end-time) → **red**, Complete Job enabled;
 *  - past end-time with an `auto_checkout_seconds` window → **red**, counting that window down.
 */
private fun deriveInProgressTimer(
    remaining: Int,
    state: JobUiState.InProgress,
    strings: JobStrings,
): InProgressTimerState {
    val yellowThresholdSec = state.checkoutBeforeMins * 60
    val autoWindow = state.autoCheckoutSeconds ?: 0
    val inAutoCheckout = remaining <= 0 && autoWindow > 0

    val color = when {
        inAutoCheckout -> InProgressColor.Red
        remaining <= 60 -> InProgressColor.Red
        remaining <= yellowThresholdSec -> InProgressColor.Yellow
        else -> InProgressColor.Green
    }

    // Complete Job is enabled from the yellow window onward (Flutter shows the checkout CTA in
    // yellow + red, hidden/disabled in green).
    val completeEnabled = remaining <= yellowThresholdSec

    val timeText: String
    val pillLabel: String
    val progress: Float
    if (inAutoCheckout) {
        val autoRemaining = (autoWindow - (-remaining)).coerceIn(0, autoWindow)
        timeText = formatMmSs(autoRemaining)
        pillLabel = strings.autoCheckoutLabel
        progress = if (autoWindow > 0) autoRemaining.toFloat() / autoWindow else 0f
    } else {
        timeText = if (remaining < 0) "-${formatMmSs(-remaining)}" else formatMmSs(remaining)
        pillLabel = strings.timeLeft
        progress = if (state.totalSeconds > 0) {
            (remaining.toFloat() / state.totalSeconds).coerceIn(0f, 1f)
        } else {
            0f
        }
    }

    // Status tooltip — time-critical (Error) states take priority, then next-job-ready, then the
    // job-extended tooltip (Figma "Colored Tooltip" 10:8540 — green Success, caret pointing up at the
    // pill). Extended is lowest so it only fills the quiet mid-job window and never masks a more urgent
    // callout. Green/yellow with nothing to say show none.
    val calloutText: String?
    val calloutIsError: Boolean
    val calloutArrow: SnabbitTooltipArrowPosition
    val calloutIcon: ImageVector?
    when {
        inAutoCheckout -> {
            calloutText = strings.autoCheckoutCallout
            calloutIsError = true
            calloutArrow = SnabbitTooltipArrowPosition.TopCenter
            calloutIcon = null
        }
        remaining <= 60 -> {
            calloutText = strings.timeUpCallout
            calloutIsError = true
            calloutArrow = SnabbitTooltipArrowPosition.TopCenter
            calloutIcon = null
        }
        state.nextJobReady -> {
            calloutText = strings.nextJobReadyCallout
            calloutIsError = false
            calloutArrow = SnabbitTooltipArrowPosition.TopCenter
            calloutIcon = null
        }
        state.extraDurationLabel != null -> {
            // "+15 min" → "Job extended by 15 min", green clock+plus icon, caret pointing up at the pill.
            // Fallback copy uses {duration}; server copy uses {mins} — replace both so either resolves.
            val extra = state.extraDurationLabel.removePrefix("+")
            calloutText = strings.jobExtendedCallout.replace("{duration}", extra).replace("{mins}", extra)
            calloutIsError = false
            calloutArrow = SnabbitTooltipArrowPosition.TopCenter
            calloutIcon = AppIcons.JobExtended
        }
        else -> {
            calloutText = null
            calloutIsError = false
            calloutArrow = SnabbitTooltipArrowPosition.None
            calloutIcon = null
        }
    }

    return InProgressTimerState(
        color = color,
        timeText = timeText,
        pillLabel = pillLabel,
        progress = progress,
        completeEnabled = completeEnabled,
        remainingSeconds = remaining,
        calloutText = calloutText,
        calloutIsError = calloutIsError,
        calloutArrow = calloutArrow,
        calloutIcon = calloutIcon,
    )
}

/* ── Previews ────────────────────────────────────────────────────────── */

private val sampleInProgress = JobUiState.InProgress(
    jobId = 739,
    customerName = "Radhika S",
    jobTiming = "10:00 AM - 11:00 AM",
    durationLabel = "60 min",
    preferences = listOf(
        JobPreference("spice_level", "Spice level", "Low"),
        JobPreference("oil_level", "Oil level", "Medium"),
    ),
    remainingSeconds = 2900,
    totalSeconds = 3600,
)

@Preview
@Composable
private fun PreviewInProgressGreen() {
    SnabbitTheme {
        val strings = rememberJobStrings()
        InProgressContent(
            state = sampleInProgress,
            timer = remember {
                mutableStateOf(
                    InProgressTimerState(
                        color = InProgressColor.Green,
                        timeText = "48:23",
                        pillLabel = strings.timeLeft,
                        progress = 0.8f,
                        completeEnabled = false,
                        remainingSeconds = 2903,
                        calloutText = null,
                        calloutIsError = false,
                    ),
                )
            },
            strings = strings,
            contentPadding = PaddingValues(0.dp),
        )
    }
}

@Preview
@Composable
private fun PreviewInProgressYellow() {
    SnabbitTheme {
        val strings = rememberJobStrings()
        InProgressContent(
            state = sampleInProgress.copy(nextJobReady = true),
            timer = remember {
                mutableStateOf(
                    InProgressTimerState(
                        color = InProgressColor.Yellow,
                        timeText = "4:12",
                        pillLabel = strings.timeLeft,
                        progress = 0.07f,
                        completeEnabled = true,
                        remainingSeconds = 252,
                        calloutText = strings.nextJobReadyCallout,
                        calloutIsError = false,
                    ),
                )
            },
            strings = strings,
            contentPadding = PaddingValues(0.dp),
        )
    }
}

@Preview
@Composable
private fun PreviewInProgressRed() {
    SnabbitTheme {
        val strings = rememberJobStrings()
        InProgressContent(
            state = sampleInProgress,
            timer = remember {
                mutableStateOf(
                    InProgressTimerState(
                        color = InProgressColor.Red,
                        timeText = "0:42",
                        pillLabel = strings.timeLeft,
                        progress = 0.01f,
                        completeEnabled = true,
                        remainingSeconds = 42,
                        calloutText = strings.timeUpCallout,
                        calloutIsError = true,
                    ),
                )
            },
            strings = strings,
            contentPadding = PaddingValues(0.dp),
        )
    }
}
