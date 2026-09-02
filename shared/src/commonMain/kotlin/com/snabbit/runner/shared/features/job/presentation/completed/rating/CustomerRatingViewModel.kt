package com.snabbit.runner.shared.features.job.presentation.completed.rating

import androidx.lifecycle.ViewModel
import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.features.job.JobAnalytics
import com.snabbit.runner.shared.features.job.data.LocationProvider
import com.snabbit.runner.shared.features.job.data.state.RunnerStateSource
import com.snabbit.runner.shared.features.job.domain.repository.JobActionRepository
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * Drives the customer-rating card on the Completed stage.
 *
 * An [androidx.lifecycle.ViewModel]; the rating POST runs on the injected process-lived [appScope] so it
 * survives the Completed screen being torn down before the call returns (ECPO-760) — NOT [viewModelScope]
 * (this is a factory-created sub-flow; see PR #452 migration notes).
 *
 * Selection is **local-only** — the smiley flips to solid and the block-customer option reveals for a
 * low rating, but nothing is POSTed. The `update_customer_rating` POST is **deferred to "Ready for next
 * job"** ([CustomerRatingUiIntent.Submit]): submitting the rating advances the backend, and Dart's
 * `current_state` poll would then tear the Completed screen down — so doing it on select cut off the
 * block-customer flow (e.g. after a 1★). On submit the rating POSTs and then `current_state` refreshes
 * to advance the lifecycle. A submit failure surfaces an error but keeps the selection so the runner can
 * retry.
 */
class CustomerRatingViewModel(
    private val jobId: Int,
    private val actions: JobActionRepository,
    private val location: LocationProvider,
    private val source: RunnerStateSource,
    /**
     * Process-lived scope for the fire-and-forget rating POST so it survives the Completed screen
     * being torn down before the call returns (ECPO-760). NOT [viewModelScope]: this ViewModel is a
     * factory-created sub-flow, and its POST must outlive it — see PR #452 migration notes.
     */
    private val appScope: CoroutineScope,
    /** Job-lifecycle instrumentation (shared Koin single, threaded from [JobViewModel]). */
    private val analytics: JobAnalytics,
) : ViewModel() {
    private val _uiState = MutableStateFlow(CustomerRatingUiState())
    val uiState: StateFlow<CustomerRatingUiState> = _uiState.asStateFlow()

    fun onIntent(intent: CustomerRatingUiIntent) {
        when (intent) {
            is CustomerRatingUiIntent.SelectRating -> selectRating(intent.rating)
            CustomerRatingUiIntent.Submit -> submit()
        }
    }

    /** Local-only: flip the smiley to solid (and reveal the block card for a low rating). No POST — the
     *  rating is sent on [submit] ("Ready for next job"). */
    private fun selectRating(rating: Int) {
        analytics.completedScreenCtaClick(ctaText = "rate_customer", rating = ratingLabel(rating))
        _uiState.update { it.copy(selectedRating = rating, isError = false) }
    }

    /** Maps the 1..5 smiley to the sheet's rating enum (1 = saddest). */
    private fun ratingLabel(rating: Int): String = when (rating) {
        1 -> "bad"
        2 -> "not_good"
        3 -> "okay"
        4 -> "good"
        else -> "great"
    }

    /**
     * "Ready for next job": POST the selected rating, then refresh `current_state` to advance. Guarded
     * against a re-tap while in flight and a no-op when nothing is selected (the CTA is gated on a
     * selection anyway). On success [isSubmitting] stays true — the button keeps its spinner until the
     * advanced envelope tears this surface down (mirrors the accept/deny submit); a failure clears it
     * and flags [isError] so the runner can retry. Runs on the injected (process-lived) [appScope] so the
     * POST survives the Completed screen being torn down (ECPO-760).
     */
    private fun submit() {
        val rating = _uiState.value.selectedRating ?: return
        if (_uiState.value.isSubmitting) return
        // "Ready for next job" tapped by the runner (the auto-return-after-20s path is host-driven).
        analytics.completedScreenCtaClick(ctaText = "ready_for_next_job", returnType = "manual")
        appScope.launch {
            _uiState.update { it.copy(isSubmitting = true, isError = false) }
            when (actions.rateCustomer(jobId, rating, location.currentLocation())) {
                is Result.Err -> {
                    _uiState.update { it.copy(isSubmitting = false, isError = true) }
                    return@launch
                }
                is Result.Ok -> Unit
            }
            // Old-flow parity: the update_customer_rating POST succeeded.
            analytics.runnerRatedTheCustomer()
            source.requestRefresh()
        }
    }
}
