package com.snabbit.runner.shared.features.job.data

import com.snabbit.runner.shared.features.job.domain.model.JobMessage
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

/**
 * The process-lived scope job-action POSTs run on, held as a Koin single so it outlives any host.
 *
 * It exists because a composition-scoped scope silently breaks the accept: the in-app host used to
 * pass `rememberCoroutineScope()`, which Compose cancels the moment the overlay leaves composition
 * (Activity destroy, KMP↔Flutter handoff, "Don't keep activities"). A cancellation between
 * [JobActionStore.beginSubmit] and the response left this store — a **single**, so it outlives the
 * composition — stuck `submitting` with no coroutine alive to settle it: a permanently spinning,
 * disabled Accept button, no completion event, no error, and (because the submit guard keys off
 * this store) every later accept silently dropped until the process restarted.
 *
 * `Dispatchers.Main.immediate` mirrors the draw-over overlay's own scope, so both New-Job surfaces
 * behave identically.
 */
class JobActionScope(
    val scope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate),
)

/**
 * Shared in-flight state for the accept/deny action — the loading spinner, the failure
 * toast, the success toast. A **process-lived Koin single** (see `jobModule`), so the two
 * New-Job surfaces — the in-app [JobViewModel] and the draw-over-apps overlay's — read and
 * write the SAME instance. That is what carries an in-flight accept from the overlay into the
 * `JobActivity` it opens: without a shared store the Activity built its own empty one and
 * re-showed a tappable, non-loading Accept mid-flight (double-submit — ECPO issue #1).
 *
 * Because it now outlives any single surface, the state is **keyed by [JobActionUiState.jobId]**
 * (stamped in [beginSubmit]); [JobViewModel]'s overlay only applies it to the New-Job card whose
 * `job_id` matches, so a lingering toast from a previous engagement can't bleed onto the next job.
 *
 * Always paired begin → succeeded/failed, so `isSubmitting` can't get stuck (the KMP
 * HTTP client times out → `failed`). In-memory only; resets on process restart.
 */
class JobActionStore {
    private val _state = MutableStateFlow(JobActionUiState())
    val state: StateFlow<JobActionUiState> = _state.asStateFlow()

    val isSubmitting: Boolean get() = _state.value.isSubmitting

    /**
     * The job id for which the deny/logout warning sheet should open, or null. Set by the draw-over-apps
     * overlay's Deny (which, unlike Accept, must NOT deny directly — it opens the app and shows the deny
     * sheet, ECPO-860 #3) and consumed by the in-app [JobViewModel]/JobScreen, which shares this single.
     */
    private val _denyFlowRequestedForJob = MutableStateFlow<Int?>(null)
    val denyFlowRequestedForJob: StateFlow<Int?> = _denyFlowRequestedForJob.asStateFlow()

    /** The overlay Deny was tapped for [jobId] → ask the in-app New-Job screen to open the deny sheet. */
    fun requestDenyFlow(jobId: Int?) { _denyFlowRequestedForJob.value = jobId }

    /** The in-app screen has opened (or no longer needs) the deny sheet — clear the pending request. */
    fun clearDenyFlowRequest() { _denyFlowRequestedForJob.value = null }

    /**
     * An accept/deny call has started for [jobId] — record WHICH [action] is in flight (so the footer
     * spins the button that was pressed, not always Accept), stamp the job (so the in-flight state
     * applies only to that card across surfaces), and clear any prior toast.
     */
    fun beginSubmit(jobId: Int?, action: JobSubmitAction, startedAtMs: Long? = null) = _state.update {
        it.copy(
            jobId = jobId,
            submitting = action,
            startedAtMs = startedAtMs,
            acceptedAtMs = null,
            errorMessage = null,
            successMessage = null,
        )
    }

    /**
     * The accept POST returned 2xx; the spinner is now held waiting for the transition rather than
     * for the network. Distinct from [submitting], which is set BEFORE the call and so cannot tell
     * "in flight" from "awaiting transition" — a distinction the healthy-path latency metric depends
     * on (see [JobActionUiState.acceptedAtMs]).
     */
    fun acceptAcknowledged(acceptedAtMs: Long) = _state.update { it.copy(acceptedAtMs = acceptedAtMs) }

    /**
     * The call returned 2xx — stop submitting and surface [message] as a success toast. Clears any
     * error so the two are mutually exclusive: [JobActionToast] shows error-before-success, so a stale
     * error must not out-rank (drop) this success.
     */
    fun succeeded(message: JobMessage) = _state.update {
        it.copy(startedAtMs = null, acceptedAtMs = null, submitting = null, successMessage = message, errorMessage = null)
    }

    /** The call failed — stop submitting and surface [message] as an error toast (clears any success). */
    fun failed(message: JobMessage) = _state.update {
        it.copy(startedAtMs = null, acceptedAtMs = null, submitting = null, errorMessage = message, successMessage = null)
    }

    /**
     * The call returned 2xx but this surface shows **no** success toast (e.g. OTP
     * check-in, which just refreshes so the next stage dismisses the sheet). Stops
     * submitting without leaving a stale [JobActionUiState.successMessage] behind —
     * [succeeded] would leak it into the toast on the next screen re-derivation.
     */
    fun finished() = _state.update {
        it.copy(startedAtMs = null, acceptedAtMs = null, submitting = null, successMessage = null, errorMessage = null)
    }

    fun clearError() = _state.update { it.copy(errorMessage = null) }

    fun clearSuccess() = _state.update { it.copy(successMessage = null) }
}

/**
 * Which New-Job action is in flight. Kept as an identity rather than a bare `isSubmitting` boolean so
 * the footer can spin the button the runner actually pressed — Deny spins Deny, Accept spins Accept —
 * and merely disable (not spin) the other. A single boolean couldn't tell the two apart, so a deny
 * showed the loading spinner on the Accept button.
 */
enum class JobSubmitAction { Accept, Deny }

/** Transient accept/deny action state held by [JobActionStore], keyed to the [jobId] it belongs to. */
data class JobActionUiState(
    /** The job this in-flight/settled action is for — overlaid only onto the matching New-Job card. */
    val jobId: Int? = null,
    /** The accept/deny action currently in flight, or null when idle. */
    val submitting: JobSubmitAction? = null,
    /**
     * When the in-flight action was submitted, for `job_accept_resolved`'s elapsed time.
     *
     * Lives HERE, not on the ViewModel, for the same reason [submitting] does: an accept begun on the
     * overlay is resolved by whichever surface observes the transition, which may be the *in-app*
     * ViewModel created afterwards. A per-VM timestamp would be null there, and the healthy-path
     * event would silently go missing exactly in the cross-surface flow.
     */
    val startedAtMs: Long? = null,
    /**
     * When the accept POST returned 2xx, or null while it is still in flight.
     *
     * [submitting] is set BEFORE the network call, so it alone cannot distinguish "POST in flight"
     * from "2xx received, awaiting the transition". Without that distinction an offer withdrawn
     * mid-POST looked identical to a healthy accept completing: the state-transition branch fired
     * `job_accept_resolved(state_transition)` with a short `ms_since_tap`, then the POST's own
     * failure fired a second event — putting a failed accept in the healthy bucket and deflating
     * the very latency distribution this instrumentation exists to measure.
     */
    val acceptedAtMs: Long? = null,
    val errorMessage: JobMessage? = null,
    val successMessage: JobMessage? = null,
) {
    /** Any accept/deny call is in flight (either button busy). */
    val isSubmitting: Boolean get() = submitting != null
}
