package com.snabbit.runner.shared.features.job.presentation.checkin

import androidx.lifecycle.ViewModel
import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.features.job.JobAnalytics
import com.snabbit.runner.shared.features.job.data.state.RunnerStateSource
import com.snabbit.runner.shared.features.job.data.asIntOrNull
import com.snabbit.runner.shared.features.job.domain.model.JobActionError
import com.snabbit.runner.shared.features.job.domain.model.JobMessage
import com.snabbit.runner.shared.features.job.domain.model.errorKind
import com.snabbit.runner.shared.features.job.domain.repository.JobActionRepository
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * Drives the check-in sheet (OTP → phone fallback → success). A stateful modal flow, so it is its own
 * MVI unit (per `shared/CLAUDE.md`) rather than a `StateFlow` + the shared `JobActionStore` overlay on
 * [JobViewModel].
 *
 * Plain class + injected [scope]. The host creates it via [JobViewModel.createCheckInViewModel] while
 * the await-check-in stage renders; the sheet reads [uiState] (null = closed) and sends
 * [CheckInUiIntent]s. Self-contained: the in-flight flag + inline error live on [CheckInUiState] (unlike
 * accept/deny, which still share `JobActionStore`).
 *
 * There is no success toast — the [CheckInStep.Success] celebration IS the confirmation. The stage
 * advance (`requestRefresh` → `IN_PROGRESS`) is **deferred** to [CheckInUiIntent.SuccessAcknowledged]
 * (fired when the success progress animation completes), so the celebration shows before this surface
 * is torn down.
 */
class CheckInViewModel(
    private val actions: JobActionRepository,
    private val source: RunnerStateSource,
    /** UI-lifetime scope, supplied by [JobViewModel] (its [viewModelScope]); the sheet's work ends with the stage. */
    private val scope: CoroutineScope,
    /** Job-lifecycle instrumentation (shared Koin single, threaded from [JobViewModel]). */
    private val analytics: JobAnalytics,
    /**
     * Stops the host-owned delayed-check-in alarm when the runner opens the sheet
     * (`core/alarm` seam, threaded from [JobViewModel]). Plain lambda so tests stay
     * DI-free; the default no-op covers iOS and unit tests.
     */
    private val silenceAlarm: () -> Unit = {},
) : ViewModel() {
    private val _uiState = MutableStateFlow<CheckInUiState?>(null)

    /** The check-in sheet state, or null when the sheet is closed. */
    val uiState: StateFlow<CheckInUiState?> = _uiState.asStateFlow()

    /** The single input channel — every check-in-sheet action flows through here. */
    fun onIntent(intent: CheckInUiIntent) {
        when (intent) {
            CheckInUiIntent.Open -> {
                // The check-in screen "Check In" CTA opens the OTP sheet.
                // The runner acted on the prompt, so stop the delayed-check-in
                // alarm now instead of letting it run out its repeat count. The
                // sound is host-owned (Dart), hence the seam.
                silenceAlarm()
                analytics.checkInScreenCtaClick("check_in")
                _uiState.value = CheckInUiState()
                analytics.checkInOtpLoad()
            }
            CheckInUiIntent.SwitchToPhone -> {
                analytics.checkInOtpCtaClick("no_otp")
                _uiState.update { it?.copy(step = CheckInStep.Phone, errorMessage = null) }
                analytics.noOtpFallbackLoad()
            }
            CheckInUiIntent.SwitchToOtp -> {
                analytics.noOtpFallbackCtaClick("use_otp_instead")
                _uiState.update { it?.copy(step = CheckInStep.Otp, errorMessage = null) }
                analytics.checkInOtpLoad()
            }
            CheckInUiIntent.Dismiss -> {
                analytics.checkInOtpModalDismissed()
                _uiState.value = null
            }
            // Progress animation done (or tapped) → advance the stage + close, once. Idempotent:
            // if the flow is already closed (e.g. a poll advanced the stage), do nothing.
            CheckInUiIntent.SuccessAcknowledged -> if (_uiState.value != null) {
                analytics.jobStartedCtaClick("ok")
                // WS5: the stage advance to IN_PROGRESS arrives via the MQTT snapshot
                // (the feature-#4 fallback was already armed at the 2xx, in runCheckIn).
                _uiState.value = null
            }
            is CheckInUiIntent.StartJob ->
                // [messageForCheckIn] maps a `failure_type=LOCATION` reject to the "not at the job
                // location" copy and a transport failure to the "poor connection" copy — never the
                // misleading "incorrect OTP" for those (ECPO-1059). The failure's coarse reason is
                // stamped on the CTA event so the funnel can tell a wrong OTP from a network drop.
                runCheckIn(
                    ::messageForCheckIn,
                    onOutcome = { error ->
                        analytics.checkInOtpCtaClick(
                            "start_job",
                            otpVerificationStatus = if (error == null) "success" else "failed",
                            errorReason = error?.errorKind(),
                        )
                    },
                ) { jobId ->
                    // No location sent → backend skips the 25m check-in geofence (intentional; also
                    // avoids the GPS-fetch delay), so a LOCATION reject is not expected in practice.
                    actions.startJob(jobId, intent.otp, null)
                }
            is CheckInUiIntent.CheckInWithPhone ->
                runCheckIn(
                    ::messageForPhoneCheckIn,
                    onOutcome = { error ->
                        analytics.noOtpFallbackCtaClick(
                            "start_job",
                            phoneVerificationStatus = if (error == null) "success" else "failed",
                            errorReason = error?.errorKind(),
                        )
                    },
                ) { jobId ->
                    // No location sent → backend skips the 25m check-in geofence (see StartJob above).
                    actions.checkInWithoutOtp(jobId, intent.phone, null, accuracyMeters = null)
                }
        }
    }

    /**
     * Shared check-in runner (OTP + no-OTP phone): flips [CheckInUiState.isSubmitting] (the Start Job
     * button shows loading), runs [action] for the current job, and on 2xx advances the sheet to its
     * [CheckInStep.Success] step. The stage advance is **deferred** to
     * [CheckInUiIntent.SuccessAcknowledged].
     *
     * Every non-2xx surfaces inline via [failureMessage] on the current step.
     */
    private fun runCheckIn(
        failureMessage: (JobActionError) -> JobMessage,
        /**
         * Fired once with the attempt outcome — null on 2xx, the [JobActionError] on failure. The caller
         * emits the OTP/phone CTA verification status plus the failure reason (ECPO-1059).
         */
        onOutcome: (error: JobActionError?) -> Unit = {},
        action: suspend (jobId: Int) -> Result<Unit, JobActionError>,
    ) {
        val jobId = currentJobId() ?: return
        if (_uiState.value?.isSubmitting == true) return
        scope.launch {
            _uiState.update { it?.copy(isSubmitting = true, errorMessage = null) }
            when (val result = action(jobId)) {
                is Result.Err -> {
                    onOutcome(result.error)
                    _uiState.update {
                        it?.copy(isSubmitting = false, errorMessage = failureMessage(result.error))
                    }
                    return@launch
                }
                is Result.Ok -> Unit
            }
            onOutcome(null)
            // Feature #4: arm the timed fallback at the 2xx (NOT at SuccessAcknowledged,
            // which fires after the success animation — by then the MQTT transition has
            // usually landed, polluting the baseline seq and false-reporting a miss).
            source.onPostAction("check_in")
            _uiState.update { it?.copy(isSubmitting = false, step = CheckInStep.Success) }
            // The Success step (the "Job Started" celebration) is now shown.
            analytics.jobStartedLoad()
        }
    }

    // ECPO-1059: a genuinely wrong OTP arrives as a server CustomError ([JobActionError.Server]) and is
    // shown verbatim — so "incorrect OTP" is NEVER the fallback for an unclassified failure any more. A
    // transport failure reads as the "poor connection" copy and everything else as the generic copy;
    // both `when`s are exhaustive so a new [JobActionError] variant is a compile error, not a silent
    // wrong-OTP claim.
    private fun messageForCheckIn(e: JobActionError): JobMessage = when (e) {
        is JobActionError.Server -> JobMessage.Server(e.message)
        JobActionError.Reassigned -> JobMessage.Reassigned
        // A LOCATION reject stays inline on the current step, but must not read as a wrong OTP.
        // Not expected with no location sent — kept as defensive mapping of the backend wire error.
        JobActionError.CheckInLocation -> JobMessage.CheckInLocation
        // The request never reached the backend — "poor connection", not a wrong OTP.
        is JobActionError.Network -> JobMessage.NetworkError
        // A backend reject with no message (and an unexpected phone-mismatch on the OTP path): generic,
        // never a false "incorrect OTP".
        else -> JobMessage.Generic
    }

    private fun messageForPhoneCheckIn(e: JobActionError): JobMessage = when (e) {
        is JobActionError.Server -> JobMessage.Server(e.message)
        JobActionError.Reassigned -> JobMessage.Reassigned
        // Same defensive mapping as [messageForCheckIn] — must not read as a phone mismatch.
        JobActionError.CheckInLocation -> JobMessage.CheckInLocation
        // A real PHONE_NUMBER failure_type IS the phone-mismatch copy (unlike the OTP path).
        JobActionError.CheckInPhoneMismatch -> JobMessage.PhoneMismatch
        // The request never reached the backend — "poor connection", not a phone mismatch.
        is JobActionError.Network -> JobMessage.NetworkError
        // A backend reject with no message: generic, never a false "phone doesn't match".
        JobActionError.Generic -> JobMessage.Generic
    }

    private fun currentJobId(): Int? =
        source.state.value?.widgetData?.get("job_id").asIntOrNull()
}
