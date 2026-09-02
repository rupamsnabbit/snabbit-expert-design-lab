package com.snabbit.runner.shared.features.job.delayedcheckin.presentation

import com.snabbit.runner.shared.core.Logger
import com.snabbit.runner.shared.core.appconfig.AppConfigStore
import com.snabbit.runner.shared.core.network.NetworkError
import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.core.session.RunnerSessionStore
import com.snabbit.runner.shared.features.job.data.asIntOrNull
import com.snabbit.runner.shared.features.job.delayedcheckin.DelayedCheckinAnalytics
import com.snabbit.runner.shared.features.job.delayedcheckin.data.decodeAwaitingCheckin
import com.snabbit.runner.shared.features.job.delayedcheckin.data.decodePreActionNudge
import com.snabbit.runner.shared.features.job.delayedcheckin.data.readJobSupportOptions
import com.snabbit.runner.shared.features.job.delayedcheckin.domain.model.SupportOption
import com.snabbit.runner.shared.features.job.delayedcheckin.domain.repository.DelayedCheckinRepository
import com.snabbit.runner.shared.core.runnerstate.RunnerStateStore
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Deferred
import kotlinx.coroutines.async
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.serialization.json.JsonObject
import kotlin.coroutines.cancellation.CancellationException

/**
 * The delayed check-in penalty section's MVI unit (LLD §5.3 behaviour
 * table). Observes the [RunnerStateStore] envelope directly — decoding only
 * its own `widget_data` slice (`delayed_checkin_penalty` + the disposition
 * ids), per that store's each-feature-decodes-its-slice doctrine — and
 * drives:
 *
 *  - the signed countdown ([DelayedCheckinUiState.remainingSeconds]) via
 *    [ReachByTicker.signedStream]. The tick pipeline keys on the **penalty
 *    payload alone** (`distinctUntilChanged` on the slice), so unrelated
 *    envelope churn (widget-name flips, id changes) never restarts the
 *    ticker; a genuinely re-anchored deadline (reset / pause-shift / next
 *    ladder step) does, via `collectLatest` — FR-07/20 need no extra code
 *    path. A payload that is *present but undecodable* keeps the last good
 *    penalty state (stale-but-valid beats a flapping footer, the
 *    RunnerStateStore principle); only the key's absence clears (FR-02).
 *  - `delayed_checkin_penalty_popup_viewed` once per deadline
 *    ([DelayedCheckinAnalytics.popupViewed] owns the dedupe, TR-11);
 *  - the "Call Support Partner" disposition funnel (FR-11/12/13): options
 *    from the mirrored app config, submit → callback toast (Ameyo, with the
 *    server-driven ack message when present) or helpline dial, with the
 *    full analytics ladder. `runnerId` and the Ameyo flag are read **live
 *    at submit time** from [RunnerSessionStore] (Dart parity: the Flutter
 *    flow reads both at tap/request time), so a profile or Remote Config
 *    settle that lands after this screen launched still takes effect.
 *
 * One-shot [effects] are collected by `JobScreen` and routed through
 * [DelayedCheckinEffectHandler]. Plain class, host-constructed with its
 * UI [scope] (`JobActivity.lifecycleScope`) — not a Koin single.
 */
class DelayedCheckinViewModel(
    private val store: RunnerStateStore,
    private val appConfig: AppConfigStore,
    private val session: RunnerSessionStore,
    private val repository: DelayedCheckinRepository,
    private val analytics: DelayedCheckinAnalytics,
    private val scope: CoroutineScope,
    private val strings: DelayedCheckinStrings = DelayedCheckinStrings(),
    private val ticker: ReachByTicker = ReachByTicker(),
    private val logger: Logger? = null,
) {

    private val _uiState = MutableStateFlow(DelayedCheckinUiState())
    val uiState: StateFlow<DelayedCheckinUiState> = _uiState.asStateFlow()

    private val _effects = Channel<DelayedCheckinEffect>(Channel.BUFFERED)
    val effects: Flow<DelayedCheckinEffect> = _effects.receiveAsFlow()

    /** Dial-mode helpline prefetch, started at [DelayedCheckinIntent.SupportClicked] (FR-13). */
    private var helplinePrefetch: Deferred<String?>? = null

    init {
        scope.launch {
            store.state
                .map {
                    val widgetData = it?.widgetData
                    Pair(
                        widgetData?.get("delayed_checkin_penalty") as? JsonObject,
                        // The deduction nudge rides as a SIBLING of the penalty slice
                        // (`widget_data.pre_action_nudges`) on the real backend payload.
                        decodePreActionNudge(widgetData),
                    )
                }
                .distinctUntilChanged()
                .collectLatest { (payload, widgetNudge) ->
                    val penalty = decodeAwaitingCheckin(payload, logger)?.copy(nudge = widgetNudge)
                    if (penalty == null) {
                        if (payload != null) {
                            // Key present but undecodable (one malformed poll): keep the
                            // last good penalty so the footer doesn't flap; the ticker for
                            // it was cancelled by collectLatest, so restart it below if
                            // there is a prior deadline to tick against.
                            logger?.w(TAG, "malformed penalty payload; keeping last good state")
                            _uiState.value.penalty?.let { previous ->
                                ticker.signedStream(previous.deadline)
                                    .map { it.coerceAtLeast(OVERRUN_SENTINEL) }
                                    .distinctUntilChanged()
                                    .collect { seconds ->
                                        _uiState.update { it.copy(remainingSeconds = seconds) }
                                    }
                            }
                        } else {
                            // FR-02: penalty resolved — clear everything, including a sheet
                            // left open and the helpline cache from this penalty session.
                            // Cancel the prefetch before dropping it: with the penalty gone its
                            // only consumer (onSubmitSucceeded) is unreachable, so an in-flight
                            // GET would otherwise run to completion with its result discarded.
                            helplinePrefetch?.cancel()
                            helplinePrefetch = null
                            _uiState.update { DelayedCheckinUiState() }
                        }
                        return@collectLatest
                    }
                    analytics.popupViewed(penalty.dedupeKey, penalty.receivedRedCards)
                    // Publish the penalty WITH its first real tick in one atomic update:
                    // setting penalty before the first tick would render the footer
                    // against the state's stale/zero remainingSeconds for a frame,
                    // making the progress fill flash full then animate back. Setting
                    // it on every tick is equivalent (same instance) and branch-free.
                    //
                    // Clamped at OVERRUN_SENTINEL then de-duped so the pipeline goes
                    // quiet once the deadline passes: `signedStream` never completes
                    // (-1, -2, -3 … forever) but every negative value renders
                    // IDENTICALLY — the footer pins the timer at "00:00"
                    // (`ReachBy(seconds.coerceAtLeast(0))`), the wash clamps to a full
                    // bar, and `isOverrun` is just `remainingSeconds < 0`. Publishing
                    // each new negative therefore changed state, and so recomposed, once
                    // a second forever for a pixel-identical UI. Overrun is the NORMAL
                    // end state of a delayed check-in and is unbounded (until the server
                    // clears the payload), so this was the dominant cost of the feature.
                    // `collectLatest` gives each penalty a fresh flow, so the atomic
                    // first-publish above still fires for every re-anchored deadline.
                    ticker.signedStream(penalty.deadline)
                        .map { it.coerceAtLeast(OVERRUN_SENTINEL) }
                        .distinctUntilChanged()
                        .collect { seconds ->
                            _uiState.update { it.copy(penalty = penalty, remainingSeconds = seconds) }
                        }
                }
        }
    }

    fun onIntent(intent: DelayedCheckinIntent) {
        when (intent) {
            DelayedCheckinIntent.SupportClicked -> onSupportClicked()
            is DelayedCheckinIntent.SubmitDisposition -> submit(intent.option)
            DelayedCheckinIntent.DismissSheet -> {
                if (!_uiState.value.submitting) {
                    _uiState.update { it.copy(supportSheet = SupportSheetState.Hidden) }
                }
            }
        }
    }

    private fun onSupportClicked() {
        analytics.ctaClicked()
        val options = readJobSupportOptions(appConfig.snapshot())
        if (options.isEmpty()) {
            // FR-11 config missing — Dart parity: an error toast, never an empty sheet.
            analytics.configMissing()
            _effects.trySend(DelayedCheckinEffect.Toast(strings.supportDetailsNotFound, success = false))
            return
        }
        if (!session.ameyoSupport.value && helplinePrefetch == null) {
            // Dial mode: resolve the number now so Submit doesn't wait on a second
            // round-trip. A failed prefetch resolves null; submit() retries then.
            //
            // The body is guarded because `scope` is the shell-wide
            // `rememberCoroutineScope()`, backed by a plain Job rather than a
            // SupervisorJob: an `async` that throws cancels its PARENT immediately,
            // at throw time — not at `await()`. An escape from fetchHelpline would
            // therefore tear down the whole shell scope (JobViewModel's collector,
            // this VM's RunnerStateStore collector, the contact handler), freezing
            // the job screen on stale state with no error and no crash. Today the
            // layers below fold failures into Result so this is latent, not live —
            // guarding keeps it that way. CancellationException is rethrown so
            // `helplinePrefetch?.cancel()` still works.
            helplinePrefetch = scope.async {
                try {
                    fetchHelpline()
                } catch (e: CancellationException) {
                    throw e
                } catch (e: Throwable) {
                    logger?.e(TAG, "helpline prefetch threw", e)
                    null
                }
            }
        }
        _uiState.update { it.copy(supportSheet = SupportSheetState.Shown(options)) }
    }

    private fun submit(option: SupportOption) {
        if (_uiState.value.submitting) return
        // Ids read live at submit time: the envelope from the store snapshot, the
        // runner id from the session mirror (a late profile settle still counts).
        val widgetData = store.snapshot()?.widgetData
        val runnerJobId = widgetData?.get("runner_job_id").asIntOrNull() ?: -1
        val jobId = widgetData?.get("job_id").asIntOrNull() ?: -1
        val runner = session.runnerId.value ?: -1
        if (runnerJobId <= 0 || jobId <= 0 || runner <= 0) {
            // TR-09: refused pre-network — same copy Dart shows for unusable ids.
            _effects.trySend(DelayedCheckinEffect.Toast(strings.supportDetailsNotFound, success = false))
            return
        }
        // One consistent mode per submission: read the flag once, use it for both
        // the request param and the success branch.
        val ameyo = session.ameyoSupport.value
        // Claim the in-flight slot SYNCHRONOUSLY, before dispatching. Setting it
        // inside `scope.launch` left the guard above reading a stale `false`: the
        // scope is `rememberCoroutineScope()` on AndroidUiDispatcher.Main, which
        // always dispatches (it does not short-circuit like Main.immediate), so the
        // flag — and the Submit button's own `enabled = … && !isSubmitting` — only
        // flipped a frame later. Two taps landing in the same frame (routine while
        // the main thread is janked, which is exactly the state during a penalty
        // render on a low-end device) both passed and fired two POSTs. POST is
        // correctly excluded from retry, so nothing downstream de-duped them: the
        // backend recorded a duplicate disposition and, in Ameyo mode, could place
        // two callbacks. Guard-then-set now runs without an intervening suspension,
        // and every caller is on the main thread, so the window is closed.
        _uiState.update { it.copy(submitting = true) }
        scope.launch {
            analytics.submitted(option.id, runnerJobId)
            try {
                val result = repository.submitDisposition(
                    runnerJobId = runnerJobId,
                    jobId = jobId,
                    runnerId = runner,
                    dispositionTag = option.id,
                    dispositionMessage = option.label,
                    ameyoSupport = ameyo,
                )
                when (result) {
                    is Result.Ok -> {
                        analytics.submissionSuccess(option.id, statusCode = null)
                        onSubmitSucceeded(ameyo = ameyo, serverMessage = result.value)
                    }
                    is Result.Err -> {
                        // Dart parity: the failure event carries the real HTTP status so
                        // dashboards can split client (4xx) from server (5xx) errors. A
                        // non-HTTP transport failure has no status → null.
                        analytics.submissionFailed(
                            option.id,
                            statusCode = (result.error as? NetworkError.HttpError)?.statusCode,
                        )
                        // Fail-with-retry (TR-08): sheet stays up with the selection.
                        _uiState.update { it.copy(submitting = false) }
                        _effects.trySend(DelayedCheckinEffect.Toast(strings.submitFailed, success = false))
                        // X.3 transient error: a transport failure (no HTTP response) is a network error.
                        analytics.submitErrorScreenLoad(isNetworkError = result.error is NetworkError.TransportError)
                    }
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Throwable) {
                logger?.e(TAG, "submitDisposition threw", e)
                analytics.submissionFailed(option.id, statusCode = null)
                _uiState.update { it.copy(submitting = false) }
                _effects.trySend(DelayedCheckinEffect.Toast(strings.submitFailed, success = false))
                // Unexpected throwable (not a mapped NetworkError) — no reliable connectivity signal.
                analytics.submitErrorScreenLoad(isNetworkError = false)
            }
        }
    }

    private suspend fun onSubmitSucceeded(ameyo: Boolean, serverMessage: String?) {
        if (ameyo) {
            // Callback mode: the backend places the call — green toast (server-driven
            // copy when the ack carries one, Dart parity), close the sheet.
            _uiState.update { it.copy(submitting = false, supportSheet = SupportSheetState.Hidden) }
            _effects.trySend(
                DelayedCheckinEffect.Toast(serverMessage ?: strings.callbackToast, success = true),
            )
            return
        }
        // Dial mode: use the prefetched number; a missed/failed prefetch retries here.
        // The cache is single-use — cleared after consumption so the next support
        // session (possibly a different widget stage or job) resolves fresh.
        val number = helplinePrefetch?.await() ?: fetchHelpline()
        helplinePrefetch = null
        if (number.isNullOrBlank()) {
            // FR-13 edge: submit landed but there is nothing to dial — sheet stays
            // so the runner can retry (the disposition is idempotent server-side).
            _uiState.update { it.copy(submitting = false) }
            _effects.trySend(DelayedCheckinEffect.Toast(strings.helplineUnavailable, success = false))
            return
        }
        analytics.callInitiated(number)
        _uiState.update { it.copy(submitting = false, supportSheet = SupportSheetState.Hidden) }
        _effects.trySend(DelayedCheckinEffect.Dial(number))
    }

    private suspend fun fetchHelpline(): String? {
        val widgetType = store.snapshot()?.widgetName.orEmpty()
        return when (val result = repository.getHelpline(widgetType = widgetType)) {
            is Result.Ok -> result.value
            is Result.Err -> {
                logger?.w(TAG, "getHelpline failed; dial unavailable")
                null
            }
        }
    }

    private companion object {
        const val TAG = "DelayedCheckinViewModel"

        /**
         * The single value published for the whole overrun. Any negative
         * `remainingSeconds` renders identically (timer pinned at "00:00", wash
         * full) and `isOverrun` only tests `< 0`, so collapsing them all onto one
         * value lets `distinctUntilChanged` stop the 1 Hz state churn while
         * keeping the overrun presentation and the secondary-CTA swap intact.
         */
        const val OVERRUN_SENTINEL = -1
    }
}
