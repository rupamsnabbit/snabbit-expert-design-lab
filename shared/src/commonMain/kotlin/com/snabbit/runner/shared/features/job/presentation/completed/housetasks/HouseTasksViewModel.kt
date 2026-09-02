package com.snabbit.runner.shared.features.job.presentation.completed.housetasks

import androidx.lifecycle.ViewModel
import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.features.job.JobAnalytics
import com.snabbit.runner.shared.features.job.domain.model.JobActionError
import com.snabbit.runner.shared.features.job.domain.model.JobMessage
import com.snabbit.runner.shared.features.job.domain.repository.JobActionRepository
import com.snabbit.runner.shared.storage.PreferenceStorage
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * Drives the post-checkout house-tasks sheet — the forced, show-once "What tasks did you do?" selector
 * on the POST_CHECKOUT stage (ECPO-528). Migrated from the Flutter `TasksDoneByRunner` +
 * `updateTaskCollectionApi` (`rate_customer.dart`).
 *
 * Plain class + injected [scope] (the "callers pass CoroutineScope" convention, same as
 * [CustomerRatingViewModel]). The host creates it via [com.snabbit.runner.shared.features.job.presentation.JobViewModel.createHouseTasksViewModel]
 * when the sheet gate opens; the sheet reads [uiState] and sends [HouseTasksUiIntent]s. Its own MVI unit,
 * so it does not add another `StateFlow` to `JobViewModel`.
 *
 * On init it fetches the selectable tasks. Submit (guarded on `isSubmitting`, requires ≥1 selected) POSTs
 * the selected keys; on 2xx it persists a per-job show-once flag, then [onSubmitted] (so the gate closes
 * immediately, before the persisted read races) and refreshes `current_state` to advance the lifecycle
 * and reveal the rating.
 *
 * @param onSubmitted called on submit success — the host flips its in-memory gate so the sheet closes.
 */
class HouseTasksViewModel(
    private val jobId: Int,
    private val actions: JobActionRepository,
    private val preferenceStorage: PreferenceStorage,
    /**
     * Process-lived scope for the fire-and-forget submit POST + show-once persist so they survive the
     * Completed screen being torn down (ECPO-760). NOT [viewModelScope]: this is a factory-created
     * sub-flow whose work must outlive it — see PR #452 migration notes.
     */
    private val appScope: CoroutineScope,
    /** Job-lifecycle instrumentation (shared Koin single, threaded from [JobViewModel]). */
    private val analytics: JobAnalytics,
    private val onSubmitted: () -> Unit,
) : ViewModel() {
    private val _uiState = MutableStateFlow(HouseTasksUiState())
    val uiState: StateFlow<HouseTasksUiState> = _uiState.asStateFlow()

    /** Count of "Try again" taps on the fetch-failure sheet — carried as `retry_attempt` and used to
     *  fire `error_screen_load` only on the sheet's FIRST appearance (a failed retry must not re-count). */
    private var fetchRetryAttempts = 0

    init {
        load()
    }

    /** The single input channel — every house-tasks-sheet action flows through here. */
    fun onIntent(intent: HouseTasksUiIntent) {
        when (intent) {
            HouseTasksUiIntent.Retry -> {
                // "Try again" on the fetch-failure sheet re-runs the fetch. Count it BEFORE reloading so
                // the CTA carries the attempt number and the reload's error branch sees it as a retry.
                fetchRetryAttempts += 1
                analytics.errorScreenCtaClick(
                    ctaText = "try_again",
                    errorType = "house_tasks_fetch_failed",
                    retryAttempt = fetchRetryAttempts,
                )
                load()
            }
            is HouseTasksUiIntent.Toggle -> toggle(intent.key)
            HouseTasksUiIntent.Submit -> submit()
        }
    }

    /** Fetches the selectable house tasks; a failure surfaces an inline error + retry. */
    private fun load() {
        _uiState.update { it.copy(isLoading = true, errorMessage = null) }
        appScope.launch {
            when (val result = actions.fetchHouseTasks(jobId)) {
                // A successful-but-empty fetch means there's nothing to report. This sheet is forced +
                // non-dismissible and its empty branch offers only Retry, so showing it would trap the
                // runner behind the scrim (rating / next-job unreachable). Close the gate instead so the
                // Completed screen underneath is reachable. (ECPO-528 review — empty-fetch trap.)
                is Result.Ok ->
                    if (result.value.isEmpty()) {
                        onSubmitted()
                    } else {
                        _uiState.update { it.copy(tasks = result.value, isLoading = false) }
                        // The tasks-done grid is now shown (non-empty fetch).
                        analytics.tasksDoneLoad(result.value.map { task -> task.key })
                    }
                is Result.Err -> {
                    _uiState.update { it.copy(isLoading = false, errorMessage = messageFor(result.error)) }
                    // The fetch-failure retry sheet is now shown (isFetchError). Fire error_screen_load
                    // only on first appearance — a failed "Try again" re-enters here but is already
                    // captured by error_screen_cta_click's retry_attempt (C1 pattern, cf. CheckInViewModel).
                    // JobActionError carries no no-connection variant, so is_network_error is false.
                    if (fetchRetryAttempts == 0) {
                        analytics.errorScreenLoad(
                            errorType = "house_tasks_fetch_failed",
                            errorFormat = "bottomsheet",
                            errorContext = "job_completed",
                            isNetworkError = false,
                            retryAvailable = true,
                            contactSupportAvailable = false,
                        )
                    }
                }
            }
        }
    }

    private fun toggle(key: String) {
        _uiState.update { state ->
            val selected = if (key in state.selectedKeys) state.selectedKeys - key else state.selectedKeys + key
            // Clear the "select at least one" hint the moment the runner picks anything.
            state.copy(selectedKeys = selected, errorMessage = null)
        }
    }

    /**
     * Submits the selected task keys (`update_task_collection`). Guards a re-tap while a POST is in
     * flight and a no-op empty selection. On 2xx: persist the show-once flag (surviving process death),
     * flip the in-memory gate via [onSubmitted] so the forced sheet closes at once, and refresh
     * `current_state`. A non-2xx keeps the grid up with an inline error.
     */
    private fun submit() {
        val state = _uiState.value
        if (state.isSubmitting) return
        // Empty selection: reject inline (the CTA stays solid + readable) rather than silently no-opping.
        if (state.selectedKeys.isEmpty()) {
            _uiState.update { it.copy(errorMessage = JobMessage.SelectTaskHint) }
            return
        }
        appScope.launch {
            _uiState.update { it.copy(isSubmitting = true, errorMessage = null) }
            when (val result = actions.submitHouseTasks(jobId, state.selectedKeys.toList())) {
                is Result.Err -> {
                    _uiState.update { it.copy(isSubmitting = false, errorMessage = messageFor(result.error)) }
                    return@launch
                }
                is Result.Ok -> Unit
            }
            analytics.tasksDoneCtaClick("submit", state.selectedKeys.toList())
            // Persist first so a relaunch on this job never re-shows the sheet, then close the gate in
            // memory (onSubmitted). Leaving POST_CHECKOUT / revealing the rating now arrives via the
            // MQTT snapshot — WS5: no current_state refresh (fail-loud if not published).
            preferenceStorage.putBool("job_tasks_submitted_$jobId", true)
            onSubmitted()
        }
    }

    private fun messageFor(e: JobActionError): JobMessage = when (e) {
        is JobActionError.Server -> JobMessage.Server(e.message)
        else -> JobMessage.Generic
    }
}
