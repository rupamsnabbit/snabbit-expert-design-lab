package com.snabbit.runner.shared.features.shift.presentation.emergencylogout
import com.snabbit.runner.shared.core.Logger
import com.snabbit.runner.shared.core.analytics.ErrorAnalytics
import com.snabbit.runner.shared.core.defaultLogger
import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.core.result.RunnerActionError
import com.snabbit.runner.shared.features.gamification.domain.model.PostActionOutcome
import com.snabbit.runner.shared.features.periodleave.domain.repository.PeriodLeaveRepository
import com.snabbit.runner.shared.features.shift.core.domain.repository.ShiftRepository
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlin.coroutines.cancellation.CancellationException

/**
 * Drives the emergency-logout sheet.
 *
 * Architecture notes:
 *  - [Load] fans out the two availability fetches in parallel via `coroutineScope { async + async }`.
 *    isLoading flips off only once BOTH settle. Emergency-logout fetch failure
 *    surfaces as [EmergencyLogoutUiState.errorMessage]; period-leave failure
 *    falls back silently (the row hides) — same posture as the Dart provider,
 *    which doesn't gate the sheet on period-leave readiness.
 *  - [Confirm] is gated on [EmergencyLogoutUiState.canConfirm] — guards against
 *    double-tap and pre-load taps. The `period_leave` flag sent to the BE comes
 *    from [EmergencyLogoutUiState.effectivePeriodLeave] (false when the row is
 *    hidden), matching Dart parity.
 *  - On confirm success: when period leave was used we surface TakeCare first
 *    (matching `TakeCareSheet.show(rootCtx, source: 'emergency_logout')` on
 *    Dart); otherwise we Finish immediately.
 */
class EmergencyLogoutViewModel(
    private val shiftRepository: ShiftRepository,
    private val periodLeaveRepository: PeriodLeaveRepository,
    private val analytics: EmergencyLogoutAnalytics,
    private val errorAnalytics: ErrorAnalytics,
    private val scope: CoroutineScope,
    /**
     * Invoked once, the moment the emergency-logout POST returns OK. The
     * host wires this to `RunnerStateStore.requestRefresh()` so Dart re-fetches
     * `current_state` immediately — without this the home stayed on the
     * pre-logout envelope until the next periodic poll.
     */
    private val onEmergencyLoggedOut: () -> Unit = {},
    /** Defaults to the platform logger (== Koin's `single<Logger>`), so the
     *  `HomeTabContent` call site and tests need not pass it. */
    private val logger: Logger = defaultLogger(),
    /**
     * Invoked with the decoded gamification outcome when the emergency-logout
     * response carries a `post_action_outcome`. The host (`HomeTabContent`)
     * wires this to `PostActionCoordinator.show(...)` on a scope that outlives
     * the sheet, so the reward/penalty popup (or waiver sheet) survives the
     * sheet dismissing. No-op when the response carries no outcome.
     */
    private val onPostAction: (PostActionOutcome) -> Unit = {},
) {
    private val _uiState = MutableStateFlow(EmergencyLogoutUiState())
    val uiState: StateFlow<EmergencyLogoutUiState> = _uiState.asStateFlow()

    private val _effects = MutableSharedFlow<EmergencyLogoutUiEffect>(extraBufferCapacity = 4)
    val effects: SharedFlow<EmergencyLogoutUiEffect> = _effects.asSharedFlow()

    /**
     * Gamification outcome stashed on a period-leave logout — presented only
     * after [EmergencyLogoutUiIntent.AcknowledgeTakeCare], so the waiver
     * sheet/popup never races the TakeCare sheet's popup window (the DS
     * bottom sheet draws above all app content). ECPO-753 follow-up.
     */
    private var pendingOutcome: PostActionOutcome? = null

    /** Count of "Try again" taps on the load-failure error body — carried as `retry_attempt`, and gates
     *  `error_screen_load` to the body's FIRST appearance (a failed retry must not re-count it). */
    private var loadRetryAttempts = 0

    init {
        load()
    }

    fun onIntent(intent: EmergencyLogoutUiIntent) {
        when (intent) {
            EmergencyLogoutUiIntent.Load -> {
                // The load-failure error body's Retry button re-dispatches Load. Count it as an
                // error-surface CTA only when that body is actually showing (errorType == Load).
                if (_uiState.value.errorType == EmergencyLogoutError.Load) {
                    loadRetryAttempts += 1
                    errorAnalytics.errorScreenCtaClick(
                        ctaText = "try_again",
                        errorType = "emergency_logout_load_failed",
                        retryAttempt = loadRetryAttempts,
                    )
                }
                load()
            }
            is EmergencyLogoutUiIntent.TogglePeriodLeave -> togglePeriodLeave(intent.checked)
            EmergencyLogoutUiIntent.Confirm -> confirm()
            EmergencyLogoutUiIntent.Dismiss -> {
                analytics.ctaGoBack()
                _effects.tryEmit(EmergencyLogoutUiEffect.Finish)
            }
            EmergencyLogoutUiIntent.AcknowledgeTakeCare -> {
                _uiState.update { it.copy(showTakeCare = false, finished = true) }
                _effects.tryEmit(EmergencyLogoutUiEffect.Finish)
                // Present the stashed outcome now the sheet chain is done —
                // the host's PostActionOverlayHost renders it (waived →
                // waiver sheet, penalty → popup) over the hosting surface.
                pendingOutcome?.let { presentOutcome(it) }
                pendingOutcome = null
            }
            EmergencyLogoutUiIntent.ErrorShown -> _uiState.update { it.copy(errorType = null) }
        }
    }

    private fun load() {
        scope.launch {
            _uiState.update { it.copy(isLoading = true, errorType = null) }
            try {
                coroutineScope {
                    // Both deferreds run in parallel — we await each one for its concrete
                    // typed Result, avoiding awaitAll's erased-list return.
                    val availabilityDeferred = async { shiftRepository.emergencyLogoutAvailability() }
                    val periodLeaveDeferred = async { periodLeaveRepository.getAvailability() }
                    val availability = availabilityDeferred.await()
                    val periodLeave = periodLeaveDeferred.await()

                    val avail = (availability as? Result.Ok)?.value
                    val pl = (periodLeave as? Result.Ok)?.value
                    _uiState.update {
                        it.copy(
                            isLoading = false,
                            availability = avail,
                            periodLeave = pl,
                            // Period-leave fetch failures fall back silently (row hides).
                            // Only the emergency-logout fetch failure blocks the sheet.
                            errorType = if (availability is Result.Err) EmergencyLogoutError.Load else null,
                        )
                    }
                    if (avail != null) {
                        analytics.sheetLoaded(
                            amountAtRisk = avail.earningLossAmount,
                            periodLeaveAvailable = pl?.remaining ?: 0,
                        )
                    }
                    // Availability fetch failed → the blocking error body (with a Retry CTA) is shown.
                    if (availability is Result.Err) {
                        fireLoadErrorOnce(isNetworkError = availability.error is RunnerActionError.NoConnection)
                    }
                }
            } catch (e: CancellationException) {
                throw e
            } catch (t: Throwable) {
                // Repository calls return `Result`, so network failures never reach
                // here — this branch only fires on genuinely unexpected throwables
                // (a mapping crash, a Koin resolution fault, an NPE). Those are
                // exactly the ones Crashlytics wants; discarding them made a
                // recurring load crash invisible to telemetry.
                logger.e(TAG, "emergency-logout load failed unexpectedly", t)
                _uiState.update { it.copy(isLoading = false, errorType = EmergencyLogoutError.Load) }
                // Unexpected throwable (mapping/DI fault) — not a connectivity error.
                fireLoadErrorOnce(isNetworkError = false)
            }
        }
    }

    /** The blocking load-failure error body just appeared → cross-cutting `error_screen_load`, once.
     *  A failed "Try again" re-enters [load] but is captured by `error_screen_cta_click`'s retry_attempt
     *  instead (C1 pattern, cf. CheckInViewModel). */
    private fun fireLoadErrorOnce(isNetworkError: Boolean) {
        if (loadRetryAttempts != 0) return
        errorAnalytics.errorScreenLoad(
            errorType = "emergency_logout_load_failed",
            errorFormat = "bottomsheet",
            errorContext = "emergency_logout",
            isNetworkError = isNetworkError,
            retryAvailable = true,
            contactSupportAvailable = false,
        )
    }

    private fun togglePeriodLeave(checked: Boolean) {
        analytics.ctaTogglePeriodLeave(selected = checked)
        _uiState.update { it.copy(periodLeaveChecked = checked) }
    }

    private fun confirm() {
        val state = _uiState.value
        if (!state.canConfirm) return
        analytics.ctaLogout(periodLeaveSelected = state.effectivePeriodLeave)
        // `isSubmitting` is raised HERE — synchronously, before the launch — not inside
        // the coroutine. `scope` is a rememberCoroutineScope() (AndroidUiDispatcher.Main,
        // NOT Main.immediate), so a body deferred to the next frame let two taps across
        // two frames both clear `canConfirm` and both POST. Emergency logout is
        // destructive and quota-limited, so a double-fire burns an allowance the runner
        // can't get back. Same guard-then-set order as `HomeViewModel.launchAction`.
        _uiState.update { it.copy(isSubmitting = true, errorType = null) }
        scope.launch {
            val usedPeriodLeave = state.effectivePeriodLeave
            when (val result = shiftRepository.emergencyLogout(periodLeave = usedPeriodLeave)) {
                is Result.Ok -> {
                    val outcome = result.value
                    analytics.confirmed(
                        waiverType = waiverTypeFor(usedPeriodLeave, outcome),
                        redCardsApplied = outcome?.redCards ?: 0,
                        amountLost = state.availability?.earningLossAmount,
                    )
                    // Fire the runner-state refresh BEFORE the screen unmounts
                    // so the host can re-poll `current_state` and the home
                    // recomposes onto the post-logout envelope.
                    // TODO(ECPO): when period leave is taken the PROFILE data also goes
                    //  stale and needs a refresh — the profile screen lands on its own
                    //  branch, so wire that refresh in once it merges.
                    onEmergencyLoggedOut()
                    if (usedPeriodLeave) {
                        // TakeCare sheet replaces the confirm sheet; flow finishes
                        // after AcknowledgeTakeCare — the gamification outcome is
                        // stashed and presented there, so the waiver sheet doesn't
                        // render under the TakeCare popup window (ECPO-753).
                        pendingOutcome = outcome
                        _uiState.update { it.copy(isSubmitting = false, showTakeCare = true) }
                    } else {
                        _uiState.update { it.copy(isSubmitting = false, finished = true) }
                        _effects.tryEmit(EmergencyLogoutUiEffect.Finish)
                        // Present AFTER Finish so the popup lands on the hosting
                        // surface as the confirm sheet is closing, not under it.
                        outcome?.let { presentOutcome(it) }
                    }
                }
                is Result.Err -> _uiState.update {
                    it.copy(isSubmitting = false, errorType = EmergencyLogoutError.Confirm)
                }
            }
        }
    }

    private fun waiverTypeFor(usedPeriodLeave: Boolean, outcome: PostActionOutcome?): String = when {
        usedPeriodLeave -> WAIVER_PERIOD_LEAVE
        outcome?.isWaived == true -> WAIVER_AUTO
        else -> WAIVER_NONE
    }

    /** Fire the waiver-shown event when a waived outcome is about to render,
     *  then hand it to the host overlay. */
    private fun presentOutcome(outcome: PostActionOutcome) {
        if (outcome.isWaived) analytics.waiverShown(redCardsWaived = outcome.redCards)
        onPostAction(outcome)
    }

    private companion object {
        const val TAG = "EmergencyLogoutVM"
        const val WAIVER_PERIOD_LEAVE = "period_leave"
        const val WAIVER_AUTO = "auto"
        const val WAIVER_NONE = "none"
    }
}
