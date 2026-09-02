package com.snabbit.runner.shared.features.job.presentation

import com.snabbit.runner.shared.features.job.JobAnalytics
import com.snabbit.runner.shared.features.job.domain.model.NewJobModel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

/**
 * Owns the job lifecycle's **derived** analytics — the four `*_screen_load` events (once per stage
 * entry) plus the two transition/timer events (`job_not_accepted`, `auto_checkout`) — driven off
 * [JobViewModel.uiState].
 *
 * Extracted from [JobViewModel] (M1) so the VM stays focused on the flow (single-responsibility) and
 * this state machine is unit-testable in isolation with an injected [scope] (the accept-expiry timer
 * in particular). The thin per-intent CTA emits stay inline in the VM's `onIntent`.
 *
 * De-dup for the stage loads is held **here, per instance** (not on the shared [JobAnalytics] single),
 * so the two new-job hosts track their own loads independently; the cross-host `job_not_accepted`
 * de-dup correctly lives on the single.
 */
class JobInstrumentation(
    private val analytics: JobAnalytics,
    private val displayMode: String,
    private val scope: CoroutineScope,
) {
    // The observed stream — set by [observe], read by the accept-expiry timer when it fires.
    private lateinit var uiState: StateFlow<JobUiState>

    private var lastStageLoadKey: String? = null

    // Jobs whose checkout was MANUAL (End Job tapped), recorded via [markManualCheckout] — lets the
    // InProgress→Completed watcher tell a manual checkout from a backend auto-checkout. Consumed on read.
    private val manualCheckoutJobs = mutableSetOf<Int?>()

    // The last-seen InProgress `auto_checkout_seconds`, captured for the `auto_checkout` event (which
    // fires on the Completed transition, by which point the InProgress state is already gone).
    private var lastAutoCheckoutSeconds: Int? = null

    // One-shot accept-window-expiry timer for the current new-job offer.
    private var acceptExpiryJob: Job? = null

    /** Start observing the lifecycle stream. Call once (from [JobViewModel.init]). */
    fun observe(state: StateFlow<JobUiState>) {
        uiState = state
        scope.launch { state.collect { onStage(it) } }
    }

    /** Record a MANUAL checkout so the InProgress→Completed watcher doesn't misread it as auto-checkout. */
    fun markManualCheckout(jobId: Int?) {
        if (jobId != null) manualCheckoutJobs.add(jobId)
    }

    private fun onStage(state: JobUiState) {
        val key = when (state) {
            is JobUiState.NewJob -> "acceptance:${state.model.jobId}"
            is JobUiState.AwaitingCheckIn -> "check_in:${state.jobId}"
            is JobUiState.InProgress -> "in_progress:${state.jobId}"
            is JobUiState.Completed -> "completed:${state.jobId}"
            JobUiState.Loading, JobUiState.NotInJobFlow -> return
        }
        if (key == lastStageLoadKey) return
        val previousKey = lastStageLoadKey
        lastStageLoadKey = key
        // Stage changed → drop any pending accept-expiry from a prior offer.
        acceptExpiryJob?.cancel()
        when (state) {
            is JobUiState.NewJob -> {
                analytics.acceptanceScreenLoad(
                    displayMode = displayMode,
                    jobType = jobTypeOf(state.model),
                    denyAvailable = state.model.isDeniable,
                    earnTotal = state.model.payout?.totalEarning,
                    earningsLineItems = state.model.payout?.lines?.map { it.labelKey }.orEmpty(),
                    checkInByTime = state.model.payout?.checkInTimeIso,
                    acceptCountdownSeconds = state.acceptRemainingSeconds,
                    penaltyNudgeVisible = state.model.showDeallocationWarning,
                )
                armAcceptExpiry(state)
            }
            is JobUiState.AwaitingCheckIn -> analytics.checkInScreenLoad(
                checkInState = if (state.isPastCheckIn) CHECK_IN_STATE_RUNNING_LATE else CHECK_IN_STATE_ON_TIME,
                earnTotal = state.payout?.totalEarning,
                checkInBonus = state.payout?.checkInAmount,
                checkInBonusForfeited = state.isPastCheckIn,
                timerState = if (state.isPastCheckIn) TIMER_STATE_RED else TIMER_STATE_GREEN,
            )
            is JobUiState.InProgress -> {
                lastAutoCheckoutSeconds = state.autoCheckoutSeconds
                val timerState = inProgressTimerState(state)
                analytics.inProgressScreenLoad(
                    timerState = timerState,
                    timeLeftSeconds = state.remainingSeconds,
                    jobDurationMinutes = state.durationMinutes,
                    extended = state.extraDurationLabel != null,
                    // "+15 min" → 15; a null/absent label yields no extension_minutes attribute.
                    extensionMinutes = state.extraDurationLabel?.let { label -> label.filter { it.isDigit() }.toIntOrNull() },
                    completeJobEnabled = timerState != TIMER_STATE_GREEN,
                    jobTiming = state.jobTiming.ifBlank { null },
                    customerPreferencesShown = state.preferences.isNotEmpty(),
                )
            }
            is JobUiState.Completed -> {
                analytics.completedScreenLoad(
                    earnTotal = state.payout?.totalEarning,
                    earningsLineItems = state.payout?.lines?.map { it.labelKey }.orEmpty(),
                )
                // Reached Completed straight from THIS job's InProgress without a manual End Job → the
                // backend auto-checked-out. Consume the manual flag on read so the set stays bounded and a
                // re-offered id can't carry a stale flag (C4/P2).
                val wasManual = manualCheckoutJobs.remove(state.jobId)
                if (previousKey == "in_progress:${state.jobId}" && !wasManual) {
                    analytics.autoCheckout(autoCheckoutAfterMinutes = lastAutoCheckoutSeconds?.let { it / SECONDS_PER_MINUTE })
                }
            }
            JobUiState.Loading, JobUiState.NotInJobFlow -> Unit
        }
    }

    /**
     * Arms a one-shot timer that fires `job_not_accepted` if the accept window lapses with the offer
     * still un-actioned. Replaced when the stage changes; the fire is guarded on the offer still being
     * live, and [JobAnalytics.jobNotAccepted] de-dups across the two new-job hosts.
     */
    private fun armAcceptExpiry(state: JobUiState.NewJob) {
        val jobId = state.model.jobId
        // Per-offer key so a genuine re-offer of the same job re-fires (the shared single de-dups the
        // SAME offer across both hosts).
        val offerKey = "$jobId:${state.model.notifiedAtIso}"
        val remaining = state.acceptRemainingSeconds
        if (remaining <= 0) return
        acceptExpiryJob = scope.launch {
            delay(remaining * MILLIS_PER_SECOND)
            val current = uiState.value
            if (current is JobUiState.NewJob && current.model.jobId == jobId && current.submittingAction == null) {
                analytics.jobNotAccepted(offerKey = offerKey, penaltyAmount = current.model.lossAmount)
            }
        }
    }

    private fun jobTypeOf(model: NewJobModel): String = when {
        model.isLongDistance -> JOB_TYPE_LONG_DISTANCE
        model.isLastHourJob -> JOB_TYPE_LAST_HOUR
        else -> JOB_TYPE_STANDARD
    }

    /** Envelope-time pill colour: red in the final minute, yellow within `checkout_before_mins`, else green. */
    private fun inProgressTimerState(state: JobUiState.InProgress): String = when {
        state.remainingSeconds <= SECONDS_PER_MINUTE -> TIMER_STATE_RED
        state.remainingSeconds <= state.checkoutBeforeMins * SECONDS_PER_MINUTE -> TIMER_STATE_YELLOW
        else -> TIMER_STATE_GREEN
    }

    private companion object {
        const val JOB_TYPE_STANDARD = "standard"
        const val JOB_TYPE_LONG_DISTANCE = "long_distance"
        const val JOB_TYPE_LAST_HOUR = "last_hour"
        const val CHECK_IN_STATE_ON_TIME = "on_time"
        const val CHECK_IN_STATE_RUNNING_LATE = "running_late"
        const val TIMER_STATE_GREEN = "green"
        const val TIMER_STATE_YELLOW = "yellow"
        const val TIMER_STATE_RED = "red"
        const val SECONDS_PER_MINUTE = 60
        const val MILLIS_PER_SECOND = 1000L
    }
}
