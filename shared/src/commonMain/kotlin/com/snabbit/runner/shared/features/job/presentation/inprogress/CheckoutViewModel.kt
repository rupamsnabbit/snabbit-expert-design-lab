package com.snabbit.runner.shared.features.job.presentation.inprogress

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
 * Drives the in-progress checkout sheet (campaign → OTP). A stateful modal flow, so it is its own MVI
 * unit (per `shared/CLAUDE.md`) rather than another `StateFlow` on [JobViewModel].
 *
 * Plain class + injected [scope] (the "callers pass CoroutineScope" convention). The host creates it via
 * [JobViewModel.createCheckoutViewModel] when the in-progress stage renders; the sheet reads [uiState]
 * (null = closed) and sends [CheckoutUiIntent]s. Self-contained: unlike accept/deny/check-in it does not
 * touch the shared `JobActionStore` — the in-flight flag + wrong-OTP error live on [CheckoutUiState].
 *
 * Success is envelope-driven: a 2xx `check_out` KEEPS the sheet up (End Job button still spinning) and
 * refreshes `current_state`; the sheet closes only when the lifecycle advance to the Completed stage
 * unmounts this whole sub-flow — so the runner sees a continuous loading state from tap to completion.
 * The post-checkout house-tasks selection is now a separate forced sheet on the Completed stage
 * (ECPO-528), not a step here.
 */
class CheckoutViewModel(
    private val actions: JobActionRepository,
    private val source: RunnerStateSource,
    /** UI-lifetime scope, supplied by [JobViewModel] (its [viewModelScope]); the sheet's work ends with the stage. */
    private val scope: CoroutineScope,
    /** Job-lifecycle instrumentation (shared Koin single, threaded from [JobViewModel]). */
    private val analytics: JobAnalytics,
    /** Called on a 2xx `check_out` so the host can tell a MANUAL checkout from a backend auto-checkout. */
    private val onManualCheckout: () -> Unit = {},
) : ViewModel() {
    private val _uiState = MutableStateFlow<CheckoutUiState?>(null)

    /** The checkout sheet state, or null when the sheet is closed. */
    val uiState: StateFlow<CheckoutUiState?> = _uiState.asStateFlow()

    /** The single input channel — every checkout-sheet action flows through here. */
    fun onIntent(intent: CheckoutUiIntent) {
        when (intent) {
            is CheckoutUiIntent.Open -> {
                // The in-progress "Complete Job" CTA opens the checkout sheet.
                analytics.inProgressScreenCtaClick("complete_job")
                _uiState.value =
                    CheckoutUiState(step = if (intent.hasCampaign) CheckoutStep.Campaign else CheckoutStep.Otp)
                // The campaign step IS the end-of-job offer-help nudge; no campaign → straight to OTP.
                if (intent.hasCampaign) analytics.offerHelpNudgeLoad() else analytics.checkoutOtpLoad()
            }
            CheckoutUiIntent.CampaignComplete -> {
                analytics.offerHelpNudgeCtaClick("okay")
                _uiState.update { it?.copy(step = CheckoutStep.Otp, errorMessage = null) }
                analytics.checkoutOtpLoad()
            }
            is CheckoutUiIntent.EndJob -> runCheckout(intent.otp)
            CheckoutUiIntent.Dismiss -> _uiState.value = null
        }
    }

    /**
     * Runs `check_out` for the current job (the End Job CTA). Flips [CheckoutUiState.isSubmitting] (the
     * button spins) and KEEPS it spinning past the 2xx — the sheet stays up until the lifecycle advance
     * to the Completed stage unmounts the sub-flow, so the loading state spans tap → completion (the POST
     * is quick; the MQTT advance can lag). The advance arrives via the MQTT snapshot, with a feature-#4
     * timed current_state fallback if it doesn't. A non-2xx surfaces an inline error and leaves the sheet
     * on the OTP step (button re-enabled).
     */
    private fun runCheckout(otp: String) {
        val jobId = currentJobId() ?: return
        if (_uiState.value?.isSubmitting == true) return
        scope.launch {
            _uiState.update { it?.copy(isSubmitting = true, errorMessage = null) }
            // cash_collected = true mirrors the Flutter `checkOutApi` (the cash-QR path is deferred).
            // Checkout sends no location (telemetry-only server-side; skipped to avoid the GPS-fetch delay).
            when (val result = actions.checkout(jobId, null, otp, cashCollected = true)) {
                is Result.Err -> {
                    // ECPO-1059: stamp the coarse failure reason so a wrong OTP is separable from a
                    // network drop / backend reject in the funnel.
                    analytics.checkoutOtpCtaClick("end_job", "failed", errorReason = result.error.errorKind())
                    _uiState.update { it?.copy(isSubmitting = false, errorMessage = messageForCheckout(result.error)) }
                    return@launch
                }
                is Result.Ok -> Unit
            }
            analytics.checkoutOtpCtaClick("end_job", "success")
            // Mark this as a MANUAL checkout so the host's InProgress→Completed watcher doesn't
            // misread the advance as an auto-checkout.
            onManualCheckout()
            // 2xx check_out: the job is done — but DON'T close the sheet here. Keep it up with the End Job
            // button still spinning ([CheckoutUiState.isSubmitting] stays true) so the runner has continuous
            // feedback from tap → completion: the check_out POST is quick while the MQTT/poll advance to the
            // Completed stage can lag several seconds, and closing on the 2xx dropped the runner back onto
            // the in-progress screen with nothing visibly happening. The sheet closes on its own when that
            // advance lands — the in-progress stage unmounts the whole checkout sub-flow (this VM with it).
            // Feature #4: arm the timed fallback so a missed transition self-heals (and is reported).
            source.onPostAction("checkout")
        }
    }

    // ECPO-1059: a genuinely wrong checkout OTP arrives as a server CustomError ([JobActionError.Server])
    // and is shown verbatim — so "incorrect OTP" is NEVER the fallback for an unclassified failure. A
    // transport failure reads as "poor connection" and everything else as generic; exhaustive `when` so
    // a new variant can't silently regress to a wrong-OTP claim.
    private fun messageForCheckout(e: JobActionError): JobMessage = when (e) {
        is JobActionError.Server -> JobMessage.Server(e.message)
        JobActionError.Reassigned -> JobMessage.Reassigned
        is JobActionError.Network -> JobMessage.NetworkError
        JobActionError.CheckInLocation, JobActionError.CheckInPhoneMismatch, JobActionError.Generic ->
            JobMessage.Generic
    }

    private fun currentJobId(): Int? =
        source.state.value?.widgetData?.get("job_id").asIntOrNull()
}
