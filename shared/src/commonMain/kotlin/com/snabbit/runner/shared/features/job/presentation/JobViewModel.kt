package com.snabbit.runner.shared.features.job.presentation

import com.snabbit.runner.shared.features.blocklist.presentation.blockcustomer.BlockCustomerStrings
import com.snabbit.runner.shared.core.CrashReporter
import com.snabbit.runner.shared.core.localization.LocalizationStore
import com.snabbit.runner.shared.core.remoteconfig.RemoteConfigGateway
import com.snabbit.runner.shared.features.job.domain.audio.JobCueAudioPlayer
import com.snabbit.runner.shared.features.blocklist.presentation.blockcustomer.BlockCustomerViewModel
import com.snabbit.runner.shared.features.blocklist.domain.repository.BlockListRepository
import com.snabbit.runner.shared.features.job.JobAnalytics
import com.snabbit.runner.shared.features.job.data.JobActionStore
import com.snabbit.runner.shared.features.job.data.JobActionUiState
import com.snabbit.runner.shared.features.job.data.JobSubmitAction
import com.snabbit.runner.shared.features.job.data.LocationProvider
import com.snabbit.runner.shared.features.job.data.state.RunnerStateSource
import com.snabbit.runner.shared.features.job.data.asIntOrNull
import com.snabbit.runner.shared.features.job.domain.repository.JobActionRepository
import com.snabbit.runner.shared.features.job.data.state.toJob
import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.features.job.domain.JobClock
import com.snabbit.runner.shared.features.job.domain.model.JobState
import com.snabbit.runner.shared.features.job.domain.model.JobActionError
import com.snabbit.runner.shared.features.job.domain.model.errorKind
import com.snabbit.runner.shared.features.job.domain.model.JobCategory
import com.snabbit.runner.shared.features.job.domain.model.JobMessage
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.snabbit.runner.shared.features.job.domain.model.NewJobModel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import com.snabbit.runner.shared.features.kavach.sos.data.gateway.SosVisibilityGateway
import com.snabbit.runner.shared.features.kavach.sos.domain.SosCoordinator
import kotlin.coroutines.cancellation.CancellationException
import com.snabbit.runner.shared.features.job.presentation.checkin.CheckInViewModel
import com.snabbit.runner.shared.features.job.presentation.inprogress.CheckoutViewModel
import com.snabbit.runner.shared.features.job.presentation.completed.rating.CustomerRatingViewModel
import com.snabbit.runner.shared.features.job.presentation.completed.housetasks.HouseTasksViewModel
import com.snabbit.runner.shared.storage.PreferenceStorage

/**
 * Drives the top-level Job screen.
 *
 * An [androidx.lifecycle.ViewModel] — constructed with the seams ([RunnerStateSource],
 * [JobActionRepository], [LocationProvider]), a [JobClock], [JobStrings], and a process-lived
 * [appScope] for teardown-surviving POSTs. The UI stream runs on [viewModelScope]. Tests construct it
 * with fakes; the Android hosts obtain it via `ViewModelProvider` so [viewModelScope] is managed.
 *
 * [uiState] composition:
 *  - the `current_state` envelope is projected to a domain `JobState` by `toJob` and
 *    mapped to render state by `JobState.toUiState`; the accept countdown is computed
 *    **once per envelope** via `JobTiming` ([JobClock]) — so it doesn't jump when
 *    an action toggles `isSubmitting`. The screen ticks the displayed countdown
 *    down locally from that value.
 *  - the in-flight accept/deny action (the shared [JobActionStore], keyed by job) is overlaid last.
 *
 * State is stream-derived, so a fresh envelope automatically advances the
 * lifecycle; the transient action overlay is the only locally-held state.
 */
class JobViewModel(
    private val source: RunnerStateSource,
    private val actions: JobActionRepository,
    private val location: LocationProvider,
    private val clock: JobClock,
    /** Block / unblock seam for the Completed-stage block flow (Koin `blockListModule`). */
    private val blockListDataSource: BlockListRepository,
    /**
     * Persists each job's ORIGINAL duration so the "extended by +X min" badge can be derived — the
     * envelope only carries the current duration. Mirrors the Flutter `on_the_job` SharedPreferences
     * path; persisted so the badge survives process death mid-job.
     */
    private val preferenceStorage: PreferenceStorage,
    /**
     * Process-lived scope for fire-and-forget job-action POSTs (accept / deny / unblock, and the rating
     * + house-tasks sub-VMs) so an in-flight call survives the host (Activity / overlay) being torn down
     * — notably the rating POST when the Completed screen auto-dismisses (ECPO-760). NOT [viewModelScope],
     * which cancels on teardown; the UI stream ([uiState]) runs on [viewModelScope].
     */
    private val appScope: CoroutineScope,
    /** Job-lifecycle instrumentation — screen loads, CTA clicks, and error surfaces (Koin single). */
    private val analytics: JobAnalytics,
    /** Strings for the reused block sub-VM (default to the English fallbacks). */
    private val blockStrings: BlockCustomerStrings = BlockCustomerStrings(),
    /** RC gateway (mirror-backed) for the reused block sub-VM's "n/max" cap. Safe no-op default. */
    private val remoteConfig: RemoteConfigGateway = RemoteConfigGateway { _, default -> default },
    /**
     * The logged-in runner's profile `service_id` (plumbed from Dart via `JobScreenExtras`), used to
     * pick the New-Job header glyph (Cook vs Expert). Null when not supplied → envelope-derived category.
     */
    private val serviceId: Int? = null,
    /**
     * In-flight accept/deny state (loading + toast). A **process-lived Koin single** in the Android
     * hosts (defaulted to a fresh instance for tests), so the draw-over-apps overlay and the in-app
     * screen share ONE store: an accept begun on the overlay is still in-flight (Accept shows loading,
     * the [submit] guard blocks a re-tap) when it opens `JobActivity` on top — ECPO issue #1. Cross-job
     * bleed is prevented by keying the state to its `jobId` (see [applyAction]).
     */
    private val actionStore: JobActionStore = JobActionStore(),
    /** App-scoped SOS coordinator — the top-nav SOS pill raises a job-independent SOS (contract §3).
     *  Nullable so tests stay DI-free; wired by the Android hosts. */
    private val sosCoordinator: SosCoordinator? = null,
    /** Backend SOS-visibility gate (Flutter parity). Nullable → always visible for tests/previews. */
    private val sosVisibility: SosVisibilityGateway? = null,
    /**
     * `display_mode` for `job_acceptance_screen_load`: [DISPLAY_MODE_FULL_SCREEN] (in-app active-job
     * overlay) or [DISPLAY_MODE_DRAWOVER] (the draw-over-apps new-job overlay host).
     */
    private val displayMode: String = DISPLAY_MODE_FULL_SCREEN,
    /** Best-effort reporter for swallowed best-effort work (e.g. the blocked-customer profile push).
     *  Nullable so tests stay DI-free; wired by the Android hosts. */
    private val crashReporter: CrashReporter? = null,
    /**
     * Stops the host-owned delayed-check-in alarm once the runner acts on the check-in prompt.
     * Threaded into [CheckInViewModel] (which owns the CTA); the alarm itself is played by the
     * Flutter host, so this is the `core/alarm` seam rather than anything audio-shaped here.
     * Default no-op keeps tests DI-free; wired by the Android hosts.
     */
    private val silenceAlarm: () -> Unit = {},
    /**
     * Plays the in-progress voice cues (half-time / T-10) natively via [JobAudioCueScheduler] — KMP-owned,
     * so they survive the eventual Flutter removal. Nullable so tests/previews stay DI-free; the Android /
     * iOS hosts wire the Koin `JobCueAudioPlayer`. Off (scheduler not created) when unwired.
     */
    private val jobCuePlayer: JobCueAudioPlayer? = null,
    /** Runner-language read model for localizing the voice cues; paired with [jobCuePlayer]. */
    private val localization: LocalizationStore? = null,
) : ViewModel() {

    // Recomputes (incl. the countdown) only when the envelope changes — not on
    // every action toggle — so tapping Accept can't nudge the timer. The raw envelope
    // is projected to a domain Job, then mapped to render state (timing + formatting).
    private val baseState: Flow<JobUiState> =
        source.state.map { rs ->
            when (rs) {
                null -> JobUiState.Loading
                else -> (rs.toJob()?.toUiState(clock) ?: JobUiState.NotInJobFlow).withServiceCategory()
            }
        }

    // Job-extension "+X min" badge. The envelope carries only the CURRENT duration, so — like the
    // Flutter on_the_job screen — persist each job's ORIGINAL duration on first sight and derive the
    // positive delta. Persisted (not memory-only) so the badge survives process death mid-job; the
    // in-memory cache avoids re-reading disk on every poll. Resolved off [resolveExtraDuration].
    private val originalDurations = mutableMapOf<Int, Int>()
    private val _extraDuration = MutableStateFlow<ExtraDuration?>(null)

    // Accept-countdown resume across process death. The envelope's notified_at can be re-stamped/absent
    // on a cold re-poll, which would restart the countdown; persist each offered job's ABSOLUTE deadline
    // on first sight and re-anchor to it thereafter (the Flutter CircularTimerWidget(persistDuration) the
    // MVI port dropped). In-memory cache avoids re-reading disk each poll; overlaid via [withAcceptDeadline].
    private val acceptDeadlines = mutableMapOf<Int, Long>()
    private val _acceptDeadline = MutableStateFlow<AcceptDeadline?>(null)

    // NOTE: the tap timestamp deliberately lives on the shared JobActionStore, NOT here — see
    // JobActionUiState.startedAtMs. A per-VM field is null in the surface that resolves a
    // cross-surface accept.

    // Report-only watchdog: fires once if the accept is STILL in flight after the timeout, so the
    // "accepted but the screen never moved" case finally produces a signal. It deliberately does
    // NOT clear the spinner — this change only measures the wedge; the decision to also break out
    // of it belongs to a follow-up, informed by what this reports.
    private var acceptWatchdogJob: Job? = null

    // The job id currently being offered as New (null when none). Tracked so that when an offer leaves the
    // screen WITHOUT an accept/deny — i.e. the backend deallocated it — its persisted accept deadline is
    // dropped. Without this, a later reassignment of the SAME job id resumes the previous (stale) countdown
    // instead of starting fresh (ECPO-860). Confined to the single [source.state] collector in [init].
    private var offeredJobId: Int? = null

    /**
     * Backend `sos_visibility.visible` — hides the job-header SOS pill outside the shift window.
     * Separate from [uiState] because that is a sealed hierarchy; threading a field through every
     * variant to carry one orthogonal flag isn't worth it. Always-true when no gateway is wired.
     */
    val sosVisible: StateFlow<Boolean> = sosVisibility?.visible ?: MutableStateFlow(true)

    val uiState: StateFlow<JobUiState> =
        combine(baseState, actionStore.state, _extraDuration, _acceptDeadline) { base, action, extra, deadline ->
            base.applyAction(action).withExtraDuration(extra).withAcceptDeadline(deadline)
        }.stateIn(viewModelScope, SharingStarted.Eagerly, JobUiState.Loading)

    /**
     * The job id for which the in-app deny/logout sheet should open (or null) — set by the overlay's
     * Deny via the shared [actionStore] and observed by JobScreen (§3). The overlay and in-app VMs are
     * different instances sharing the one process-lived store, so this crosses that surface boundary.
     */
    val denyFlowRequestedForJob: StateFlow<Int?> = actionStore.denyFlowRequestedForJob

    // ── Post-checkout house-tasks show-once gate (ECPO-528) ──
    // Job ids whose house tasks are already submitted — persisted from a prior session (hydrated in
    // [init]) or flipped in memory the instant [createHouseTasksViewModel]'s submit succeeds. Gates
    // [tasksSheetForJob] so the forced tasks sheet shows at most once per job.
    private val _tasksSubmitted = MutableStateFlow<Set<Int>>(emptySet())

    /** Job ids already read from persisted storage, so each is checked from disk at most once. */
    private val tasksSubmissionChecked = mutableSetOf<Int>()

    /**
     * Job ids whose persisted show-once flag has already been read (hydrated in [init]). The gate below
     * waits for a job to land here before it may open, so an already-submitted job on a process-death
     * relaunch no longer flashes the forced sheet (+ a wasted fetch) in the window before the async read.
     */
    private val _tasksChecked = MutableStateFlow<Set<Int>>(emptySet())

    /**
     * The job whose post-checkout house-tasks sheet should show (POST_CHECKOUT and not yet submitted),
     * or null when none. A single show-once gate: a repeated Completed emission for the same job never
     * stacks a second sheet, and it closes the instant that job enters [_tasksSubmitted]. Stays null
     * until that job's persisted flag has been read ([_tasksChecked]) so it can't open before hydration.
     */
    val tasksSheetForJob: StateFlow<Int?> =
        combine(uiState, _tasksSubmitted, _tasksChecked) { s, submitted, checked ->
            val jobId = (s as? JobUiState.Completed)?.jobId ?: return@combine null
            if (jobId !in checked) null else jobId.takeIf { it !in submitted }
        }.stateIn(viewModelScope, SharingStarted.Eagerly, null)

    // Derived-analytics collaborator — owns the stage `*_screen_load`s + the transition/timer events
    // (`job_not_accepted`, `auto_checkout`). Extracted from this VM (M1) so it stays focused on the flow;
    // started in [init]. Its stage de-dup is per-instance (each new-job host tracks independently).
    private val instrumentation =
        JobInstrumentation(analytics = analytics, displayMode = displayMode, scope = viewModelScope)

    // In-progress voice cues (half-time / T-10), played natively (KMP-owned, Flutter-exit-ready).
    // Sibling of [instrumentation]; off when the host doesn't wire a player (tests/previews).
    private val audioCueScheduler: JobAudioCueScheduler? =
        if (jobCuePlayer != null && localization != null) {
            JobAudioCueScheduler(jobCuePlayer, localization, remoteConfig, viewModelScope, analytics)
        } else {
            null
        }

    init {
        // Resolve the per-job original duration off the raw envelope stream (kept independent of
        // [uiState] to avoid a feedback loop). First envelope for a job persists its duration; a
        // later, larger duration surfaces the extension badge.
        viewModelScope.launch {
            source.state.collect { rs ->
                val job = rs?.toJob()
                // Stamp every subsequent job event with the job it belongs to. Set from the envelope
                // (not at the tap) so screen-load and error events are attributed too, and so the id
                // survives a process restart mid-lifecycle.
                analytics.setActiveJob(currentJobId())
                (job as? JobState.InProgress)?.let {
                    resolveExtraDuration(it.jobId, it.durationMinutes)
                }
                // Persist / re-anchor the accept-countdown deadline so it resumes (not restarts) after a
                // kill; and when a job leaves the offer unaccepted (the backend deallocated it), drop its
                // deadline so a reassignment starts fresh (ECPO-860). Skipped for the pre-first-push null.
                if (rs != null) reconcileAcceptDeadline(job)
            }
        }

        // Hydrate the house-tasks show-once gate: the first time a POST_CHECKOUT job is seen, read
        // whether its tasks were already submitted (persisted, surviving process death) and, if so, seed
        // [_tasksSubmitted] so the forced sheet never re-shows for it. Each job is read from disk once.
        viewModelScope.launch {
            uiState.collect { s ->
                val jobId = (s as? JobUiState.Completed)?.jobId ?: return@collect
                if (!tasksSubmissionChecked.add(jobId)) return@collect
                if (preferenceStorage.getBool("job_tasks_submitted_$jobId") == true) {
                    _tasksSubmitted.update { it + jobId }
                }
                // Mark checked only AFTER the read so the gate stays shut until hydration lands.
                _tasksChecked.update { it + jobId }
            }
        }

        // Job-lifecycle derived analytics — stage `*_screen_load`s + the transition/timer events, observed
        // off the SAME uiState stream that drives the UI. Owned by [JobInstrumentation] (M1).
        instrumentation.observe(uiState)

        // In-progress voice cues (half-time / T-10), observed off the SAME uiState stream. No-op when
        // the host didn't wire a player (tests/previews).
        audioCueScheduler?.observe(uiState)
    }

    /** Best-effort push of the runner's current blocked-customer count to the analytics profile (absolute
     *  set; needs the live total, which the block list provides). Runs on the process-lived [appScope]. */
    private fun refreshBlockedCustomersProfile() {
        appScope.launch {
            try {
                analytics.setBlockedCustomers(blockListDataSource.getBlockedCustomers().size)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Throwable) {
                // A failed count fetch just skips the profile push — never surfaces to the runner, but
                // leave a breadcrumb so a systemic failure isn't invisible.
                crashReporter?.report(e, mapOf("op" to "refreshBlockedCustomersProfile"))
            }
        }
    }

    /** The `screen_name` attribute for cross-cutting events (top-panel taps) at the current stage. */
    private fun screenNameFor(state: JobUiState): String = when (state) {
        is JobUiState.NewJob -> JobAnalytics.SCREEN_ACCEPTANCE
        is JobUiState.AwaitingCheckIn -> JobAnalytics.SCREEN_CHECK_IN
        is JobUiState.InProgress -> JobAnalytics.SCREEN_IN_PROGRESS
        is JobUiState.Completed -> JobAnalytics.SCREEN_COMPLETED
        JobUiState.Loading, JobUiState.NotInJobFlow -> ""
    }

    /**
     * The block-customer sheet on the Completed stage (reuses the blocklist module's
     * [BlockCustomerViewModel] + BlockCustomerSheet), null when closed. Created on
     * [JobUiIntent.OpenBlockFlow] from the current Completed customer/job; the sheet runs its own
     * Confirm → block / max-reached "unblock to block" flow.
     */
    private val _blockCustomer = MutableStateFlow<BlockCustomerViewModel?>(null)
    val blockCustomer: StateFlow<BlockCustomerViewModel?> = _blockCustomer.asStateFlow()

    /** The job whose customer the runner just blocked → the block card shows its Unblock state. */
    private val _blockedForJobId = MutableStateFlow<Int?>(null)
    val blockedForJobId: StateFlow<Int?> = _blockedForJobId.asStateFlow()

    /** True while the Completed-screen Unblock call is in flight — gates its button so it can't be
     *  double-tapped into two unblock requests (ECPO #9). */
    private val _unblockInProgress = MutableStateFlow(false)
    val unblockInProgress: StateFlow<Boolean> = _unblockInProgress.asStateFlow()

    /** Fires once a block succeeds → the Completed screen shows the "customer blocked" toast. */
    private val _blockedToast = Channel<Unit>(Channel.BUFFERED)
    val blockedToast: Flow<Unit> = _blockedToast.receiveAsFlow()

    /** Fires when the header Help pill is tapped → the JobScreen host opens the "Need help?"
     *  sheet (NeedHelpSheet). One-shot so a re-tap re-opens without stale state. */
    private val _openHelp = Channel<Unit>(Channel.BUFFERED)
    val openHelp: Flow<Unit> = _openHelp.receiveAsFlow()

    /**
     * Builds the rate-customer ViewModel for the Completed stage — reusing the standalone
     * [CustomerRatingViewModel] with this ViewModel's action/location seams. Runs on [actionScope],
     * NOT [scope]: the rating POST is fire-and-forget and must survive the Completed screen
     * auto-dismissing. When `current_state` advances off POST_CHECKOUT the host tears down
     * (`JobActivity.finish()` cancels [scope]) before the POST returns — on [scope] that cancels the
     * call and the rating is never stored (ECPO-760). The screen creates it (keyed on the job) when
     * the Completed stage renders.
     */
    fun createRatingViewModel(jobId: Int): CustomerRatingViewModel =
        CustomerRatingViewModel(
            jobId = jobId,
            actions = actions,
            location = location,
            source = source,
            appScope = appScope,
            analytics = analytics,
        )

    /**
     * Builds the post-checkout house-tasks sub-flow ViewModel for the Completed stage (ECPO-528) — its
     * own MVI unit (state + intents on [HouseTasksViewModel]). The screen creates it (keyed on the job)
     * when [tasksSheetForJob] is non-null. On submit success the VM persists the show-once flag and calls
     * [onSubmitted] here, which flips the in-memory gate immediately so the forced sheet closes without
     * waiting on the (racing) persisted read.
     */
    fun createHouseTasksViewModel(jobId: Int): HouseTasksViewModel =
        HouseTasksViewModel(
            jobId = jobId,
            actions = actions,
            preferenceStorage = preferenceStorage,
            // appScope (process-lived): the submit POST + show-once persist must survive the Completed
            // screen auto-dismissing — same ECPO-760 reasoning as createRatingViewModel above.
            appScope = appScope,
            analytics = analytics,
            onSubmitted = {
                _tasksSubmitted.update { it + jobId }
                // Feature #4: arm the timed fallback for the rating-reveal transition
                // (the VM lost its own source in the shift-jobs merge; the host has it).
                source.onPostAction("house_tasks")
            },
        )

    /**
     * Builds the checkout sub-flow ViewModel for the in-progress stage — its own MVI unit (state +
     * intents live on [CheckoutViewModel], not here). The screen creates it (keyed on the job) when the
     * in-progress stage renders; leaving the stage unmounts it (so the sheet closes with the stage).
     */
    fun createCheckoutViewModel(): CheckoutViewModel =
        CheckoutViewModel(
            actions = actions,
            source = source,
            scope = viewModelScope,
            analytics = analytics,
            // Record a MANUAL checkout so the InProgress→Completed watcher doesn't misfire auto_checkout.
            onManualCheckout = { instrumentation.markManualCheckout(currentJobId()) },
        )

    /**
     * Builds the check-in sub-flow ViewModel for the await-check-in stage — its own MVI unit (state +
     * intents live on [CheckInViewModel], not here). The screen creates it (keyed on the job) when the
     * check-in stage renders; leaving the stage unmounts it (so the sheet closes with the stage).
     */
    fun createCheckInViewModel(): CheckInViewModel =
        CheckInViewModel(
            actions = actions,
            source = source,
            scope = viewModelScope,
            analytics = analytics,
            // Opening the sheet acknowledges the delayed-check-in alert — stop its alarm.
            silenceAlarm = silenceAlarm,
        )

    /** The single input channel — every screen action flows through here. */
    fun onIntent(intent: JobUiIntent) {
        when (intent) {
            // Accept sends no location (telemetry-only server-side; skipped to avoid the GPS-fetch delay).
            JobUiIntent.Accept -> submit(JobMessage.JobAccepted, JobSubmitAction.Accept) { jobId -> actions.acceptJob(jobId, null) }
            JobUiIntent.Deny -> submit(JobMessage.JobDenied, JobSubmitAction.Deny) { jobId -> actions.denyJob(jobId, location.currentLocation()) }
            // Overlay Deny: don't deny directly — ask the in-app screen to open the deny sheet (§3).
            JobUiIntent.RequestDenyFlow -> actionStore.requestDenyFlow(currentJobId())
            JobUiIntent.DenyFlowShown -> actionStore.clearDenyFlowRequest()
            JobUiIntent.Refresh -> source.requestRefresh()
            JobUiIntent.ErrorShown -> actionStore.clearError()
            JobUiIntent.SuccessShown -> actionStore.clearSuccess()

            // Post-checkout house-tasks: the runner dismissed the forced sheet after a fetch error (it
            // becomes dismissible only then). Close the gate in memory for this job — like an empty fetch
            // (onSubmitted): NOT persisted, so a relaunch re-fetches (which may succeed).
            is JobUiIntent.DismissHouseTasks -> _tasksSubmitted.update { it + intent.jobId }

            // Header pills — UI-only stubs. TODO(host): wire TapSos to the SafetyShield
            // SOS trigger and TapHelp to the help-centre destination (emit a one-shot
            // SOS pill → raise a manual, job-independent SOS (contract §3); AppSosHost (shell) renders
            // the alert + navigates. Non-blocking + best-effort.
            JobUiIntent.TapSos -> {
                analytics.topPanelCtaClick(ctaText = "sos", screenName = screenNameFor(uiState.value))
                sosCoordinator?.let { c ->
                    viewModelScope.launch {
                        try {
                            c.raiseManual()
                        } catch (e: CancellationException) {
                            throw e
                        } catch (e: Throwable) {
                            // best-effort — the coordinator owns SOS state/telemetry
                        }
                    }
                }
            }
            // Help → open the "Need help?" sheet (NeedHelpSheet), collected by the
            // JobScreen host off [openHelp] — parity with the Flutter home Help chip.
            JobUiIntent.TapHelp -> {
                analytics.topPanelCtaClick(ctaText = "help", screenName = screenNameFor(uiState.value))
                _openHelp.trySend(Unit)
            }

            // System back while a job is active (the host consumes it) — record the tap.
            JobUiIntent.BackPressed -> analytics.jobBackPressed(screenName = screenNameFor(uiState.value))

            // ── Completed → block-customer sub-flow ──
            JobUiIntent.OpenBlockFlow -> {
                // The "Block" tap on the Completed screen (fires whether or not the sheet then opens).
                analytics.completedScreenCtaClick(ctaText = "block_customer")
                (uiState.value as? JobUiState.Completed)?.let { c ->
                    val customerId = c.customerId ?: return@let
                    // Sheet is opening (customer resolved). Uses the opaque customer_id, not the name (PII —
                    // S1). trigger_rating lives on the reused rating VM, not here, so it's omitted (gap).
                    analytics.blockConfirmationLoad(customerId = customerId, triggerRating = null)
                    _blockCustomer.value = BlockCustomerViewModel(
                        customerId = customerId,
                        jobId = c.jobId,
                        dataSource = blockListDataSource,
                        strings = blockStrings,
                        scope = viewModelScope,
                        // Wired on [scope] (not the sheet's composition) so a block that lands after the
                        // sheet is dismissed still flags the card + fires the toast (ECPO review finding).
                        onBlocked = { onIntent(JobUiIntent.CustomerBlocked) },
                        // RC gateway (mirror-backed) for the reused block sub-VM's "n/max" cap (base branch).
                        remoteConfig = remoteConfig,
                    )
                }
            }
            // "No" / scrim before a block. Emit the CTA only when a sheet was actually open, so the
            // leave-Completed safety-net dismiss (screen LaunchedEffect) isn't counted as a tap.
            JobUiIntent.DismissBlockFlow -> {
                if (_blockCustomer.value != null) analytics.blockConfirmationCtaClick(ctaText = "no")
                _blockCustomer.value = null
            }
            // Block succeeded (from the sheet's `blocked` one-shot): flag the card's Unblock state,
            // fire the toast, and close the sheet. The screen stays on Completed until "Ready for next job".
            JobUiIntent.CustomerBlocked -> {
                analytics.blockConfirmationCtaClick(ctaText = "yes")
                _blockedForJobId.value = (uiState.value as? JobUiState.Completed)?.jobId
                _blockedToast.trySend(Unit)
                _blockCustomer.value = null
                // People-property: refresh the blocked-customer count from the source of truth.
                refreshBlockedCustomersProfile()
            }
            JobUiIntent.UnblockCustomer -> (uiState.value as? JobUiState.Completed)?.let { c ->
                val customerId = c.customerId ?: return@let
                if (_unblockInProgress.value) return@let // guard a double unblock while one is in flight
                // Old-flow parity: unblock CTA tapped (fires on the tap, before the API).
                analytics.ratingCustomerUnblockCta(unblockedCustomerId = customerId)
                appScope.launch {
                    _unblockInProgress.value = true
                    try {
                        blockListDataSource.unblock(customerId, c.jobId)
                        _blockedForJobId.value = null
                        // People-property: refresh the blocked-customer count after the unblock lands.
                        refreshBlockedCustomersProfile()
                    } catch (e: CancellationException) {
                        throw e
                    } catch (e: Throwable) {
                        // Unblock failed — leave the card in its Unblock (still-blocked) state so the
                        // runner can retry; there's no dedicated error surface here (mirrors the sheet's
                        // own inline handling), so we deliberately don't clear the flag.
                    } finally {
                        _unblockInProgress.value = false
                    }
                }
            }
        }
    }

    /**
     * Runs an accept/deny action for the current job: records which [action] is in flight on the
     * shared [JobActionStore] (keyed to this job, so the footer spins the pressed button), calls the
     * data source [block], and on success refreshes `current_state` (the new envelope advances the
     * lifecycle). On failure, surfaces a message — 409 reads as "reassigned", everything else generic.
     */
    private fun submit(
        successMessage: JobMessage,
        action: JobSubmitAction,
        block: suspend (jobId: Int) -> Result<Unit, JobActionError>,
    ) {
        val jobId = currentJobId() ?: return
        // Guarded per JOB, not globally: a double-tap on the job in flight must be swallowed, but a
        // leftover in-flight entry for a DIFFERENT job must never block this one. The global check
        // meant one stuck action silently dropped every subsequent accept, for every job, until the
        // process restarted — the "can't accept jobs" complaint.
        val inFlight = actionStore.state.value
        if (inFlight.submitting != null && inFlight.jobId == jobId) return
        appScope.launch {
            val tapMs = clock.nowMillis()
            if (action == JobSubmitAction.Accept) acceptWatchdogJob?.cancel()
            actionStore.beginSubmit(jobId, action, startedAtMs = tapMs)
            val result = try {
                block(jobId)
            } catch (e: CancellationException) {
                // Defence in depth: [appScope] is process-lived, so this should not happen — but the
                // store is a shared single, and anything that cancels mid-flight would otherwise
                // strand it `submitting` with no coroutine left to settle it. Clear it (no toast —
                // the runner didn't fail, we lost track) and re-throw, as structured concurrency
                // requires. Only clears if the store still describes THIS submit.
                if (storeDescribes(jobId, action)) actionStore.finished()
                throw e
            }
            // Old-flow parity: the accept/deny outcome event fired after the API call, regardless of result.
            when (action) {
                JobSubmitAction.Accept -> analytics.acceptJobButtonClicked()
                JobSubmitAction.Deny -> analytics.denyJobButtonClicked()
            }
            when (result) {
                is Result.Err -> {
                    // The per-job guard deliberately lets ANOTHER job's submit begin while this one
                    // is still in flight — so by the time this late result lands, the store may
                    // describe that job. Settling it here anyway would kill the live submit's
                    // spinner mid-flight, pin THIS job's error toast on that card, and re-enable
                    // its buttons (a double-submit window). Same shape as the cancellation guard
                    // above. Analytics below stay unconditional — they are this action's outcome
                    // regardless of who owns the store now.
                    val isNetworkError = result.error is JobActionError.Network
                    val toastShown = storeDescribes(jobId, action)
                    if (toastShown) actionStore.failed(messageFor(result.error))
                    if (action == JobSubmitAction.Accept) {
                        // Unconditional: this is the ACTION'S outcome, true whoever owns the store.
                        analytics.acceptResolved(
                            resolvedBy = RESOLVED_BY_API_ERROR,
                            msSinceTap = clock.nowMillis() - tapMs,
                            errorKind = result.error.errorKind(),
                            isNetworkError = isNetworkError,
                            jobId = jobId,
                        )
                    }
                    // Accept/deny failure surfaces as a red toast (no retry / support CTA here).
                    // Gated on the toast having ACTUALLY been shown, unlike the outcome above: this
                    // event means "a surface was displayed", so emitting it when the guard skipped
                    // the toast would inflate the error funnel with surfaces no runner ever saw.
                    if (toastShown) {
                        analytics.errorScreenLoad(
                            errorType = "job_action_failed",
                            errorFormat = "toast",
                            errorContext = JobAnalytics.SCREEN_ACCEPTANCE,
                            // Previously hardcoded false, which collapsed "no internet" and "the backend
                            // rejected this" into one indistinguishable bucket in the error funnel.
                            isNetworkError = isNetworkError,
                            retryAvailable = false,
                            contactSupportAvailable = false,
                            jobId = jobId,
                        )
                    }
                    return@launch
                }
                is Result.Ok -> Unit
            }
            // Feature #4: arm the timed fallback the instant the action is 2xx — BEFORE the
            // toast hold below — so the baseline seq is captured pre-transition. Arming after
            // the hold would read a post-transition baseline (the MQTT snapshot usually beats
            // the 1.5 s hold) and false-report a miss on the healthy path.
            source.onPostAction( when (action) {
                JobSubmitAction.Accept -> "job_accept"
                JobSubmitAction.Deny   -> "job_deny"
            },
            )
            // The offer is resolved — drop its persisted accept deadline so stale keys don't accumulate
            // and a re-offer of the same job id can't resurrect a past countdown.
            clearAcceptDeadline(jobId)
            when (action) {
                // Accept: KEEP the in-flight state (spinner on, both buttons disabled) past the 2xx. The
                // accept isn't "done" for the runner until the job actually advances off New — and the
                // POST is quick while the MQTT/poll advance that swaps the surface to check-in can lag
                // several seconds. Clearing `submitting` on the 2xx left that whole gap showing a
                // tappable, non-spinning Accept + a re-enabled Deny. So hold the spinner until
                // [reconcileAcceptDeadline] sees the accepted job leave New and clears it. No success
                // toast — the transition to check-in is itself the confirmation.
                // Arm the report-only watchdog here: this is the exact moment the runner starts
                // waiting on a transition that may never arrive. Guarded like the terminal
                // transitions: a late 2xx for a superseded submit re-arming would CANCEL the
                // current accept's watchdog (armAcceptWatchdog starts by cancelling), silently
                // dropping its timeout event.
                JobSubmitAction.Accept -> if (storeDescribes(jobId, action)) {
                    // Mark the 2xx on the store BEFORE arming: from here the spinner is waiting on
                    // the transition, not on the network, and only from here may the transition
                    // branch claim a healthy resolution (see JobActionUiState.acceptedAtMs).
                    actionStore.acceptAcknowledged(clock.nowMillis())
                    armAcceptWatchdog(jobId, tapMs)
                }
                // Deny: surface the success toast + let the deny/logout sheet close itself (it watches
                // `successMessage`), then briefly hold so the toast registers before the stage advance.
                JobSubmitAction.Deny -> if (storeDescribes(jobId, action)) {
                    actionStore.succeeded(successMessage)
                    delay(SUCCESS_HOLD_MILLIS)
                }
            }
        }
    }

    /**
     * True while the shared [actionStore] still describes THIS submit. Every terminal transition
     * (failed / succeeded / finished / watchdog re-arm) must pass it: the per-job guard allows a
     * different job's submit to take the store over while this one is in flight, and a late result
     * settling blindly would clobber that live submit's state.
     */
    private fun storeDescribes(jobId: Int, action: JobSubmitAction): Boolean {
        val s = actionStore.state.value
        return s.jobId == jobId && s.submitting == action
    }

    /**
     * Reports (does not fix) an accept that is still in flight [JobAnalytics.TIMEOUT_MS] after the
     * 2xx. Guarded on the store still showing THIS job submitting, so a transition that lands during
     * the wait — or a different job taking over the store — produces nothing.
     */
    private fun armAcceptWatchdog(jobId: Int, tapMs: Long) {
        acceptWatchdogJob?.cancel()
        acceptWatchdogJob = appScope.launch {
            delay(JobAnalytics.TIMEOUT_MS)
            val settled = actionStore.state.value
            if (settled.jobId == jobId && settled.submitting == JobSubmitAction.Accept) {
                analytics.acceptResolved(
                    resolvedBy = RESOLVED_BY_TIMEOUT,
                    msSinceTap = clock.nowMillis() - (settled.startedAtMs ?: tapMs),
                    jobId = jobId,
                )
            }
        }
    }

    /**
     * Coarse failure class for [JobAnalytics.acceptResolved]. Deliberately not an HTTP status: the
     * domain error already carries the only distinction that changes how we read the number — a 409
     * race (expected, benign) versus an actual failure.
     */
    private fun messageFor(e: JobActionError): JobMessage = when (e) {
        is JobActionError.Server -> JobMessage.Server(e.message)
        JobActionError.Reassigned -> JobMessage.Reassigned
        else -> JobMessage.Generic
    }

    private fun currentJobId(): Int? =
        source.state.value?.widgetData?.get("job_id").asIntOrNull()

    /**
     * Resolves the "extended by +X min" badge for an in-progress job. The envelope carries only the
     * CURRENT duration, so the ORIGINAL is persisted on first sight ([PreferenceStorage], surviving
     * process death) and cached in memory; the badge is the positive delta. Mirrors the Flutter
     * `on_the_job` SharedPreferences logic (`duration − original`).
     */
    private suspend fun resolveExtraDuration(jobId: Int?, durationMinutes: Int?) {
        if (jobId == null || durationMinutes == null) return
        val original = originalDurations[jobId] ?: run {
            val stored = preferenceStorage.getInt("job_original_duration_$jobId")
                ?: durationMinutes.also { preferenceStorage.putInt("job_original_duration_$jobId", it) }
            originalDurations[jobId] = stored
            stored
        }
        val extra = (durationMinutes - original).coerceAtLeast(0)
        _extraDuration.value = ExtraDuration(jobId, label = if (extra > 0) "+$extra min" else null)
    }

    /** Overlays the resolved extension badge onto the matching in-progress state (no-op otherwise). */
    private fun JobUiState.withExtraDuration(extra: ExtraDuration?): JobUiState =
        if (this is JobUiState.InProgress && extra != null && extra.jobId == jobId && extra.label != null) {
            copy(extraDurationLabel = extra.label)
        } else {
            this
        }

    /** The per-job extension delta ("+15 min"), or a null label when the job hasn't been extended. */
    private data class ExtraDuration(val jobId: Int, val label: String?)

    /**
     * Reconciles the accept-countdown deadline against the latest concrete envelope ([job] is the projected
     * state, null for a non-JOB widget; only called once an envelope has been pushed — never the pre-first-
     * push null). The currently-offered New job persists / re-anchors its deadline via [resolveAcceptDeadline]
     * so the countdown survives a process kill; and when the job that WAS being offered is no longer the
     * current New offer without having been accepted/denied here (the backend deallocated it), its persisted
     * deadline is dropped — otherwise a later reassignment of the SAME job id would resume the previous,
     * stale countdown instead of starting fresh (ECPO-860). A fresh process never observes that intermediate
     * transition, so the cold-relaunch resume from disk is unaffected.
     */
    private suspend fun reconcileAcceptDeadline(job: JobState?) {
        val offered = (job as? JobState.New)?.model?.jobId
        val previous = offeredJobId
        if (previous != null && previous != offered) {
            clearAcceptDeadline(previous)
            if (_acceptDeadline.value?.jobId == previous) _acceptDeadline.value = null
            // A successful Accept keeps its in-flight state (spinner + Deny disabled) alive past the POST
            // until HERE — the moment the accepted job leaves the New stage, the real end of "accepting".
            // Stop it now so the spinner ends exactly at the transition. Guarded on `submitting != null`
            // so it only ends a still-pending accept and never wipes a settled deny's success toast.
            val settled = actionStore.state.value
            if (settled.jobId == previous && settled.submitting != null) {
                // This is the real end of "accepting" — the only place a held accept resolves
                // successfully today, so it is where the healthy-path latency has to be measured.
                if (settled.submitting == JobSubmitAction.Accept) {
                    // Only an accept that actually reached 2xx may claim the healthy resolution.
                    // `submitting` is set BEFORE the POST, so without this an offer withdrawn (or
                    // already reassigned) while the call was still in flight reported
                    // `state_transition` with a short ms_since_tap — a FAILED accept landing in the
                    // healthy bucket, deflating the latency distribution for exactly the slow
                    // accepts this exists to measure — and then emitted a second event when the
                    // POST returned `api_error`. Below still runs unguarded: the store must settle
                    // either way, or a 2xx arriving after the offer moved on would strand it.
                    if (settled.acceptedAtMs != null) {
                        // Read off the SHARED store, so this fires even when the surface resolving the
                        // accept isn't the one that submitted it (overlay → in-app handoff).
                        settled.startedAtMs?.let { tapMs ->
                            analytics.acceptResolved(
                                resolvedBy = RESOLVED_BY_STATE_TRANSITION,
                                msSinceTap = clock.nowMillis() - tapMs,
                                // `previous`, not the ambient id: setActiveJob already ran at the top
                                // of this same collector tick, so the ambient one is the envelope
                                // that REPLACED this job — null when it moved to a non-job widget.
                                jobId = previous,
                            )
                        }
                    }
                    acceptWatchdogJob?.cancel()
                }
                actionStore.finished()
            }
        }
        settleAcceptThatMovedUnobserved(offered)
        offeredJobId = offered
        (job as? JobState.New)?.let { resolveAcceptDeadline(it.model) }
    }

    /**
     * Settles an accept whose job left New while NO ViewModel was watching.
     *
     * The branch above can only fire on an observed transition (`previous != offered`), so a VM
     * constructed AFTER the state moved has `offeredJobId == null` and can never settle: verified,
     * a fresh VM whose first envelope is already CheckIn leaves the shared store on
     * `submitting = Accept` forever and emits no resolution. That is the overlay → in-app handoff —
     * the overlay accepts, opens the app and is dismissed, and if the transition lands before the
     * in-app VM is constructed, nobody observes it. The watchdog, alive on the process-lived
     * [appScope] after the overlay VM died, then fires RESOLVED_BY_TIMEOUT ~10s later for an accept
     * that SUCCEEDED — a false timeout on the healthy path, in a flow the draw-over overlay exists
     * to serve (the backgrounded case), polluting the very distribution this instrumentation
     * produces.
     *
     * Conditions mirror the observed-transition branch: only a 2xx'd accept ([acceptedAtMs]) may
     * claim the healthy resolution — while the POST is still in flight it owns the store — and only
     * when its job is no longer the offered New job, which is what "it moved" means here.
     * Self-limiting: settling clears the store, so later envelopes fall through. Racing the other
     * surface is safe for the same reason — both read the same store, so whoever settles first
     * clears it and the other sees nothing.
     */
    private fun settleAcceptThatMovedUnobserved(offered: Int?) {
        val pending = actionStore.state.value
        if (pending.submitting != JobSubmitAction.Accept) return
        if (pending.acceptedAtMs == null) return // POST still in flight — it owns the settle
        val acceptedJob = pending.jobId ?: return
        if (acceptedJob == offered) return // still the live offer; nothing has moved
        pending.startedAtMs?.let { tapMs ->
            analytics.acceptResolved(
                resolvedBy = RESOLVED_BY_STATE_TRANSITION,
                msSinceTap = clock.nowMillis() - tapMs,
                jobId = acceptedJob,
            )
        }
        acceptWatchdogJob?.cancel()
        actionStore.finished()
    }

    /**
     * The accept watchdog runs on the process-lived [appScope] and captures this ViewModel, so
     * without this a screen torn down mid-accept retains the whole graph until the 10s timer
     * elapses — and multiplies when the runner bounces in and out. Cancelling here also stops a
     * dead surface's timer reporting on a store some other surface has since taken over.
     */
    override fun onCleared() {
        acceptWatchdogJob?.cancel()
        super.onCleared()
    }

    /**
     * Persists the accept-countdown ABSOLUTE deadline for an offered job on first sight and re-anchors to
     * it thereafter, so the countdown resumes (not restarts) after a process kill — the envelope's
     * notified_at can be re-stamped/absent on a cold re-poll. Deadline = (notified_at ?: now) +
     * timer_duration; persisted (surviving process death) and cached in memory (avoids re-reading disk
     * each poll). Mirrors the Flutter CircularTimerWidget(persistDuration) the MVI port dropped.
     */
    private suspend fun resolveAcceptDeadline(model: NewJobModel) {
        val jobId = model.jobId ?: return
        val deadline = acceptDeadlines[jobId] ?: run {
            val key = acceptDeadlineKey(jobId)
            val stored = preferenceStorage.getLong(key) ?: run {
                val start = model.notifiedAtIso?.let { clock.parseEpochMillis(it) } ?: clock.nowMillis()
                (start + model.timerDurationSec * 1000L).also { preferenceStorage.putLong(key, it) }
            }
            acceptDeadlines[jobId] = stored
            stored
        }
        _acceptDeadline.value = AcceptDeadline(jobId, deadline, model.timerDurationSec)
    }

    /**
     * Drops a job's persisted + in-memory accept-countdown deadline — called when the offer is resolved
     * (accept / deny) or deallocated — so stale keys don't accumulate and a re-offer of the same job id
     * starts a fresh countdown instead of resuming the previous one.
     */
    private suspend fun clearAcceptDeadline(jobId: Int) {
        acceptDeadlines.remove(jobId)
        preferenceStorage.remove(acceptDeadlineKey(jobId))
    }

    private fun acceptDeadlineKey(jobId: Int): String = "job_accept_deadline_$jobId"

    /**
     * Overlays the persisted accept deadline onto the matching NewJob, recomputing the remaining seconds
     * from now so the countdown resumes at the right point after a relaunch (no-op otherwise). The screen
     * ticks down locally from this seed (rememberAcceptCountdown re-keys on it).
     */
    private fun JobUiState.withAcceptDeadline(deadline: AcceptDeadline?): JobUiState =
        if (this is JobUiState.NewJob && deadline != null && deadline.jobId == model.jobId) {
            val remaining = ((deadline.deadlineMillis - clock.nowMillis()) / 1000L)
                .coerceIn(0L, deadline.totalSeconds.toLong()).toInt()
            copy(acceptRemainingSeconds = remaining, acceptTotalSeconds = deadline.totalSeconds)
        } else {
            this
        }

    /** The persisted absolute accept-countdown deadline (epoch millis) for a specific offered job. */
    private data class AcceptDeadline(val jobId: Int, val deadlineMillis: Long, val totalSeconds: Int)

    /**
     * Overrides the New-Job header category from the runner's profile [serviceId] (Cook vs Expert).
     * Leaves the envelope-derived category when [serviceId] is absent (null → no override). The
     * envelope's own category field is unreliable, so the profile service_id is the authoritative
     * Cook signal (COOK_SERVICE_ID). Mirrors the override dropped in the MVI refactor.
     */
    private fun JobUiState.withServiceCategory(): JobUiState =
        if (this is JobUiState.NewJob) {
            JobCategory.forServiceId(serviceId)?.let { copy(model = model.copy(category = it)) } ?: this
        } else {
            this
        }

    // The action overlay now applies only to NewJob (accept/deny). Check-in owns its own in-flight
    // state on CheckInViewModel; every other stage ignores the store. The store is a process-lived
    // single shared with the overlay surface, so overlay it only when the action's job matches THIS
    // card — otherwise a settled toast from a previous engagement would bleed onto the next job.
    private fun JobUiState.applyAction(action: JobActionUiState): JobUiState = when (this) {
        is JobUiState.NewJob -> if (action.jobId == model.jobId) copy(
            submittingAction = action.submitting,
            errorMessage = action.errorMessage,
            successMessage = action.successMessage,
        ) else this
        else -> this
    }

    companion object {
        /** `display_mode` = in-app active-job overlay (the default host). */
        const val DISPLAY_MODE_FULL_SCREEN = "full_screen"

        /** `display_mode` = the draw-over-apps new-job overlay host. */
        const val DISPLAY_MODE_DRAWOVER = "drawover"

        /**
         * How long to keep the `NewJob` surface up showing the success toast before
         * requesting the refreshed envelope (which advances the stage / dismisses
         * the overlay). Brief — just enough for the toast to register.
         */
        private const val SUCCESS_HOLD_MILLIS = 1500L


        /** The job left New — the healthy resolution. */
        private const val RESOLVED_BY_STATE_TRANSITION = "state_transition"

        /** The POST itself failed; the toast is showing and the buttons are live again. */
        private const val RESOLVED_BY_API_ERROR = "api_error"

        /** 2xx, but still spinning at the threshold — the candidate wedge. Reported, not fixed. */
        private const val RESOLVED_BY_TIMEOUT = "timeout"
    }
}
