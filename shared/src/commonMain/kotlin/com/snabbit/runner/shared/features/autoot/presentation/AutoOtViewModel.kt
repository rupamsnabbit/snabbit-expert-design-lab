package com.snabbit.runner.shared.features.autoot.presentation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.snabbit.runner.shared.core.analytics.AnalyticsTracker
import com.snabbit.runner.shared.core.analytics.ErrorAnalytics
import com.snabbit.runner.shared.core.network.AppErrorType
import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.core.result.RunnerActionError
import com.snabbit.runner.shared.features.autoot.domain.AutoOtTrigger
import com.snabbit.runner.shared.features.autoot.domain.model.AutoOtDenyReason
import com.snabbit.runner.shared.features.autoot.domain.model.AutoOtDetails
import com.snabbit.runner.shared.features.autoot.domain.repository.AutoOtRepository
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlin.time.Duration.Companion.minutes

/**
 * Drives the Auto-OT sheet — the full Flutter `AutoOtProvider` state machine
 * (offer → confirm → loading → success | expired | failure), the client-side
 * expiry timer, and the 6 analytics events. Observes the [trigger] the
 * `AutoOtCoordinator` derives from the runner-state stream and drives its own
 * visibility: the overlay renders nothing when [AutoOtUiState.step] is null.
 *
 * D1: `androidx.lifecycle.ViewModel` + `viewModelScope` — never an injected scope.
 * The `trigger` flow + [onAccepted] refresh callback are passed in (rather than the
 * coordinator object) to keep the VM decoupled + trivially testable.
 */
class AutoOtViewModel(
    trigger: StateFlow<AutoOtTrigger>,
    private val repository: AutoOtRepository,
    private val analytics: AnalyticsTracker,
    /**
     * Arm the realtime post-action refresh after an accept OR a reject/dismiss (Flutter
     * `_refreshCurrentState()`) — carries a short telemetry label. Wired to
     * `AutoOtCoordinator.onPostAction` → `RunnerStateStore.onPostAction` (WS5 feature #4).
     */
    private val onPostAction: (String) -> Unit,
    /**
     * Tell the coordinator the current offer is consumed (terminal step or dismissed) so it resets
     * its one-shot trigger — otherwise a recreated shell VM would replay the stale offer. Wired to
     * `AutoOtCoordinator.onOfferConsumed`.
     */
    private val onConsumed: () -> Unit = {},
) : ViewModel() {

    private val _uiState = MutableStateFlow(AutoOtUiState())
    val uiState: StateFlow<AutoOtUiState> = _uiState.asStateFlow()

    private var expiryJob: Job? = null

    // Cross-cutting error events for the Failure sheet — built from the same injected tracker.
    private val errorAnalytics = ErrorAnalytics(analytics)

    /** Count of "Try again" taps on the Failure sheet — carried as `retry_attempt`, and gates
     *  `error_screen_load` to the sheet's FIRST appearance (a failed retry must not re-count it). */
    private var failureRetryAttempts = 0

    init {
        viewModelScope.launch {
            trigger.collect { t ->
                when (t) {
                    is AutoOtTrigger.Offer -> onOffer(t.details)
                    AutoOtTrigger.Preempt -> onPreempt()
                    AutoOtTrigger.Cancelled -> expireIfActive()
                    AutoOtTrigger.None -> onTriggerCleared()
                }
            }
        }
    }

    fun onIntent(intent: AutoOtUiIntent) {
        when (intent) {
            AutoOtUiIntent.Confirm -> moveToConfirm()
            AutoOtUiIntent.Submit -> if (_uiState.value.step == AutoOtStep.Confirm) accept()
            AutoOtUiIntent.Retry -> if (_uiState.value.step == AutoOtStep.Failure) {
                // "Try again" on the Failure sheet re-runs accept(). Count it BEFORE re-submitting so the
                // CTA carries the attempt number and the reload's error branch treats it as a retry.
                failureRetryAttempts += 1
                errorAnalytics.errorScreenCtaClick(
                    ctaText = "try_again",
                    errorType = "auto_ot_failed",
                    retryAttempt = failureRetryAttempts,
                )
                accept()
            }
            // The redesign dropped the in-body "Close"/"Go back" buttons, so the sheet ✕ is the only
            // decline affordance. Behaviour is step-dependent:
            AutoOtUiIntent.Dismiss -> when (_uiState.value.step) {
                // Offer ✕ = the explicit reject → fires `ot_rejected` (REJECTED), preserving Flutter
                // analytics parity for the removed "Close" button.
                AutoOtStep.Offer -> {
                    analytics.track(EVENT_REJECTED, props())
                    rejectAndClose(AutoOtDenyReason.REJECTED)
                }
                // Confirm ✕ = dismiss (DISMISSED, no analytics) — Flutter's scrim/back behaviour.
                AutoOtStep.Confirm -> rejectAndClose(AutoOtDenyReason.DISMISSED)
                // Failure sheet ✕ = dismiss of an error surface → error_screen_cta_click(dismiss) before
                // closing (no API to reject).
                AutoOtStep.Failure -> {
                    errorAnalytics.errorScreenCtaClick(ctaText = "dismiss", errorType = "auto_ot_failed")
                    hide()
                }
                // Terminal sheets just close, no API. On Success the accept already ran + refreshed
                // (see [accept]); Expired has nothing to reject. Loading is non-dismissible in the UI,
                // so ✕/scrim can't fire there — the branch is defensive only.
                AutoOtStep.Success, AutoOtStep.Expired, AutoOtStep.Loading, null -> hide()
            }
            // Success "Go back" / Expired "OK" → close a terminal sheet (no API).
            AutoOtUiIntent.Acknowledge -> hide()
        }
    }

    // ── trigger reactions ────────────────────────────────────────────────

    private fun onOffer(details: AutoOtDetails) {
        val current = _uiState.value
        // Already showing this exact request → ignore (belt-and-suspenders; the coordinator dedupes too).
        if (current.step != null && current.details?.requestId == details.requestId) return
        expiryJob?.cancel()
        // Fresh offer → reset the Failure-sheet retry counter so a prior offer's retries don't leak in.
        failureRetryAttempts = 0
        _uiState.value = AutoOtUiState(step = AutoOtStep.Offer, details = details)
        analytics.track(EVENT_POPUP_SHOWN, props(details) + ("expiry_duration" to details.expiryDurationMinutes))
        startExpiryTimer(details.expiryDurationMinutes)
    }

    private fun onPreempt() {
        // A job / suspension preempts a still-pending offer (Flutter dismissPopup(CANCELLED)).
        // Flutter early-returns on success/idle, so terminal + in-flight steps are left alone.
        val step = _uiState.value.step ?: return
        if (step in PREEMPTIBLE) rejectAndClose(AutoOtDenyReason.CANCELLED_DUE_TO_JOB_ASSIGNMENT)
    }

    private fun onTriggerCleared() {
        // auto_ot left the stream (Flutter reset()). Close a still-pending offer, but never yank
        // a terminal sheet the user hasn't acknowledged (esp. Success right after accept, whose
        // own requestRefresh removes auto_ot from the next envelope).
        val step = _uiState.value.step ?: return
        if (step in PREEMPTIBLE) hide()
    }

    // ── user intents ─────────────────────────────────────────────────────

    private fun moveToConfirm() {
        if (_uiState.value.step != AutoOtStep.Offer) return
        _uiState.update { it.copy(step = AutoOtStep.Confirm) }
        analytics.track(EVENT_CONFIRM_CLICKED, props())
    }

    private fun accept() {
        val details = _uiState.value.details ?: return
        val id = details.requestId ?: return
        _uiState.update { it.copy(step = AutoOtStep.Loading, submitting = true, error = null) }
        analytics.track(EVENT_ACCEPT_CLICKED, props(details))
        viewModelScope.launch {
            val result = repository.accept(id)
            // Expiry may have fired during the call — only advance if still Loading (Flutter's race note).
            if (_uiState.value.step != AutoOtStep.Loading) {
                _uiState.update { it.copy(submitting = false) }
                return@launch
            }
            expiryJob?.cancel()
            when (result) {
                is Result.Ok -> {
                    _uiState.update { it.copy(step = AutoOtStep.Success, submitting = false) }
                    analytics.track(EVENT_SUCCESS, props(details))
                    onPostAction(POST_ACTION_ACCEPT)
                    onConsumed()
                }
                is Result.Err -> {
                    val appError = result.error.toAppErrorType()
                    _uiState.update {
                        it.copy(step = AutoOtStep.Failure, submitting = false, error = appError)
                    }
                    // First entry into the Failure sheet → error_screen_load (once). A failed "Try again"
                    // re-enters accept() but is already captured by error_screen_cta_click's retry_attempt.
                    if (failureRetryAttempts == 0) {
                        errorAnalytics.errorScreenLoad(
                            errorType = "auto_ot_failed",
                            errorFormat = "bottomsheet",
                            errorContext = "overtime",
                            isNetworkError = appError == AppErrorType.NO_INTERNET,
                            retryAvailable = true,
                            contactSupportAvailable = false,
                        )
                    }
                    onConsumed()
                }
            }
        }
    }

    private fun rejectAndClose(reason: AutoOtDenyReason) {
        val id = _uiState.value.details?.requestId
        hide()
        if (id != null) viewModelScope.launch { repository.reject(id, reason) } // best-effort (Flutter swallows)
        onPostAction(POST_ACTION_REJECT) // Flutter refreshes current_state after a dismiss/reject too
    }

    private fun hide() {
        expiryJob?.cancel()
        expiryJob = null
        _uiState.value = AutoOtUiState()
        onConsumed()
    }

    // ── expiry timer (viewModelScope, not an injected scope) ──────────────

    private fun startExpiryTimer(minutes: Int?) {
        val m = minutes ?: return
        if (m <= 0) return
        expiryJob = viewModelScope.launch {
            delay(m.minutes)
            expireIfActive()
        }
    }

    /** Flip an active (non-terminal) offer to Expired + fire `ot_expired`. Shared by the client
     *  expiry timer and a server cancellation ([AutoOtTrigger.Cancelled] → Flutter `handleExpired`). */
    private fun expireIfActive() {
        val step = _uiState.value.step
        if (step != null && step in EXPIRABLE) {
            expiryJob?.cancel()
            _uiState.update { it.copy(step = AutoOtStep.Expired, submitting = false) }
            analytics.track(EVENT_EXPIRED, props())
            onConsumed()
        }
    }

    private fun props(details: AutoOtDetails? = _uiState.value.details): Map<String, Any?> = mapOf(
        "request_id" to details?.requestId,
        // "EndOt" / "StartOt" — the exact Flutter `otType.name` value, to preserve dashboards.
        "ot_type" to details?.otType?.name,
    )

    private fun RunnerActionError.toAppErrorType(): AppErrorType = when (this) {
        RunnerActionError.NoConnection -> AppErrorType.NO_INTERNET
        RunnerActionError.Server -> AppErrorType.SERVER_DOWN
        RunnerActionError.Unauthorized -> AppErrorType.SECURITY_ERROR
        is RunnerActionError.Unknown -> AppErrorType.OTHER_ERROR
    }

    private companion object {
        val PREEMPTIBLE = setOf(AutoOtStep.Offer, AutoOtStep.Confirm)
        val EXPIRABLE = setOf(AutoOtStep.Offer, AutoOtStep.Confirm, AutoOtStep.Loading)

        const val EVENT_POPUP_SHOWN = "ot_popup_shown"
        const val EVENT_CONFIRM_CLICKED = "ot_confirm_clicked"
        const val EVENT_ACCEPT_CLICKED = "ot_accept_clicked"
        const val EVENT_SUCCESS = "ot_success"
        const val EVENT_EXPIRED = "ot_expired"
        const val EVENT_REJECTED = "ot_rejected"

        // WS5 feature-#4 post-action telemetry labels (surface which OT transition missed the
        // MQTT snapshot in `mqtt_post_action_fallback`); mirror lunch_accept / lunch_deny.
        const val POST_ACTION_ACCEPT = "auto_ot_accept"
        const val POST_ACTION_REJECT = "auto_ot_reject"
    }
}
