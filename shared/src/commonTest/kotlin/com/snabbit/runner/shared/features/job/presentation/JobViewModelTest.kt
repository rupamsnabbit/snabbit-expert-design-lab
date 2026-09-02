package com.snabbit.runner.shared.features.job.presentation

import com.snabbit.runner.shared.core.analytics.FakeAnalyticsTracker
import com.snabbit.runner.shared.core.network.AppErrorType
import com.snabbit.runner.shared.features.blocklist.domain.repository.BlockListRepository
import com.snabbit.runner.shared.features.blocklist.data.remote.FakeBlockListRepository
import com.snabbit.runner.shared.features.job.FakeJobActionRepository
import com.snabbit.runner.shared.features.job.JobAnalytics
import com.snabbit.runner.shared.features.job.FakeJobClock
import com.snabbit.runner.shared.features.job.FakeLocationProvider
import com.snabbit.runner.shared.features.job.FakeRunnerStateSource
import com.snabbit.runner.shared.storage.InMemoryPreferenceStorage
import com.snabbit.runner.shared.storage.PreferenceStorage
import com.snabbit.runner.shared.features.job.IN_PROGRESS_JSON
import com.snabbit.runner.shared.features.job.NEW_JOB_JSON
import com.snabbit.runner.shared.features.job.POST_CHECKOUT_JSON
import com.snabbit.runner.shared.features.job.data.JobActionStore
import com.snabbit.runner.shared.features.job.data.JobSubmitAction
import com.snabbit.runner.shared.features.job.data.LocationProvider
import com.snabbit.runner.shared.features.job.data.state.RunnerStateSource
import com.snabbit.runner.shared.features.job.domain.repository.JobActionRepository
import com.snabbit.runner.shared.features.job.domain.JobClock
import com.snabbit.runner.shared.features.job.domain.model.JobActionError
import com.snabbit.runner.shared.features.job.domain.model.JobCategory
import com.snabbit.runner.shared.features.job.domain.model.JobLocation
import com.snabbit.runner.shared.features.job.domain.model.JobMessage
import com.snabbit.runner.shared.features.job.domain.model.JobWidgetName
import com.snabbit.runner.shared.features.job.envelope
import com.snabbit.runner.shared.features.job.presentation.completed.rating.CustomerRatingUiIntent
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.cancel
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import kotlin.test.AfterTest
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertIs
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

@OptIn(ExperimentalCoroutinesApi::class)
class JobViewModelTest {

    // JobViewModel now runs its UI stream on viewModelScope, which needs a Main dispatcher in commonTest.
    @BeforeTest
    fun setUpMain() = Dispatchers.setMain(UnconfinedTestDispatcher())

    @AfterTest
    fun tearDownMain() = Dispatchers.resetMain()

    /** VM whose fire-and-forget POSTs run on an [UnconfinedTestDispatcher] appScope (eager to completion). */
    private fun TestScope.viewModel(
        source: RunnerStateSource,
        actions: JobActionRepository = FakeJobActionRepository(),
        location: LocationProvider = FakeLocationProvider(),
        clock: JobClock = FakeJobClock(),
        blockListDataSource: BlockListRepository = FakeBlockListRepository(),
        preferenceStorage: PreferenceStorage = InMemoryPreferenceStorage(),
        actionStore: JobActionStore = JobActionStore(),
        serviceId: Int? = null,
        analytics: JobAnalytics = JobAnalytics(FakeAnalyticsTracker()),
    ): JobViewModel = JobViewModel(
        source = source,
        actions = actions,
        location = location,
        clock = clock,
        blockListDataSource = blockListDataSource,
        preferenceStorage = preferenceStorage,
        appScope = CoroutineScope(UnconfinedTestDispatcher(testScheduler)),
        analytics = analytics,
        actionStore = actionStore,
        serviceId = serviceId,
    )

    private fun newJobSource() = FakeRunnerStateSource(envelope(JobWidgetName.NEW_JOB, NEW_JOB_JSON))

    @Test
    fun rating_postRunsOnAppScope_survivingViewModelTeardown() = runTest {
        // ECPO-760: the customer-rating POST must outlive the Completed screen auto-dismissing (the host
        // tears the ViewModel down, cancelling its viewModelScope). createRatingViewModel therefore runs
        // the POST on the injected process-lived [appScope], NOT viewModelScope. StandardTestDispatcher
        // keeps the launch pending until we advance, proving the POST lands on appScope regardless.
        val repo = FakeJobActionRepository()
        val appScope = CoroutineScope(StandardTestDispatcher(testScheduler))
        val vm = JobViewModel(
            source = FakeRunnerStateSource(envelope(JobWidgetName.POST_CHECKOUT, POST_CHECKOUT_JSON)),
            actions = repo,
            location = FakeLocationProvider(),
            clock = FakeJobClock(),
            blockListDataSource = FakeBlockListRepository(),
            preferenceStorage = InMemoryPreferenceStorage(),
            appScope = appScope,
            analytics = JobAnalytics(FakeAnalyticsTracker()),
        )
        val ratingVm = vm.createRatingViewModel(jobId = 93120)

        // Rating is deferred to "Ready for next job" (Submit); selection alone posts nothing.
        ratingVm.onIntent(CustomerRatingUiIntent.SelectRating(2))
        // Rating is deferred to Submit ("Ready for next job"); selection alone posts nothing.
        ratingVm.onIntent(CustomerRatingUiIntent.Submit)
        advanceUntilIdle()

        // POST fired on the process-lived appScope → rating persists across teardown.
        assertEquals(listOf(93120 to 2), repo.rateCustomerCalls)
        appScope.cancel()
    }

    @Test
    fun tapHelp_emitsOpenHelp_forTheHostToOpenTheNeedHelpSheet() = runTest {
        val vm = viewModel(newJobSource())
        val received = mutableListOf<Unit>()
        val collectJob = launch { vm.openHelp.collect { received += it } }

        vm.onIntent(JobUiIntent.TapHelp)
        advanceUntilIdle()
        collectJob.cancel()

        assertEquals(1, received.size)
    }

    @Test
    fun mapsCurrentStateIntoUiState() = runTest {
        val state = viewModel(newJobSource()).uiState.value
        assertIs<JobUiState.NewJob>(state)
        assertEquals(739, state.model.jobId)
    }

    @Test
    fun newJob_categoryFromServiceId_cookVsExpert() = runTest {
        // No serviceId → envelope-derived category (Expert for the default fixture).
        val expert = viewModel(newJobSource()).uiState.value
        assertIs<JobUiState.NewJob>(expert)
        assertEquals(JobCategory.Expert, expert.model.category)

        // serviceId 2 (COOK_SERVICE_ID) → Cook header glyph override.
        val cook = viewModel(newJobSource(), serviceId = 2).uiState.value
        assertIs<JobUiState.NewJob>(cook)
        assertEquals(JobCategory.Cook, cook.model.category)
    }

    @Test
    fun inProgress_seedsCountdownFromEndTime() = runTest {
        val end = "2026-06-27T11:00:00+05:30"
        // now = 0, end parses to 900_000ms → 900s remaining; duration 60 → 3600s total.
        val clock = FakeJobClock(now = 0L, parsed = mapOf(end to 900_000L))
        val json = """{"job_id":739,"end_time":"$end","duration":60}"""
        val vm = viewModel(FakeRunnerStateSource(envelope(JobWidgetName.IN_PROGRESS, json)), clock = clock)

        val state = vm.uiState.value
        assertIs<JobUiState.InProgress>(state)
        assertEquals(900, state.remainingSeconds)
        assertEquals(3600, state.totalSeconds)
    }

    @Test
    fun inProgress_extensionBadge_derivedFromStoredOriginalDuration() = runTest {
        val source = FakeRunnerStateSource(
            envelope(JobWidgetName.IN_PROGRESS, """{"job_id":739,"duration":60}"""),
        )
        val vm = viewModel(source)
        advanceUntilIdle()

        // First sight of the job persists 60 as its original duration → no extension badge yet.
        val first = vm.uiState.value
        assertIs<JobUiState.InProgress>(first)
        assertNull(first.extraDurationLabel)

        // Backend extends the job to 75 min → "+15 min" derived against the stored original.
        source.emit(envelope(JobWidgetName.IN_PROGRESS, """{"job_id":739,"duration":75}"""))
        advanceUntilIdle()
        val extended = vm.uiState.value
        assertIs<JobUiState.InProgress>(extended)
        assertEquals("+15 min", extended.extraDurationLabel)
    }

    @Test
    fun accept_callsAcceptWithoutLocation_noRefresh() = runTest {
        val actions = FakeJobActionRepository()
        val source = newJobSource()
        val vm = viewModel(source, actions = actions)

        vm.onIntent(JobUiIntent.Accept)
        // Feature #4 (F-A regression): the fallback arms at the 2xx, BEFORE the SUCCESS_HOLD
        // toast hold — so the engine captures a pre-transition baseline seq. Assert it's
        // already armed before advancing past the hold.
        runCurrent()
        assertEquals(listOf("job_accept"), source.postActions, "armed at 2xx, before the toast hold")
        // Success holds briefly (so the toast shows) before the surface tears down — advance past it.
        advanceUntilIdle()

        assertEquals(1, actions.acceptCalls.size)
        assertEquals(739, actions.acceptCalls.single().first)
        // Accept no longer fetches/sends location (skipped to avoid the GPS-fetch delay).
        assertNull(actions.acceptCalls.single().second)
        // WS5: stage advance arrives via MQTT — no EAGER current_state refresh (only the timed fallback).
        assertEquals(0, source.refreshCount)
        val state = vm.uiState.value
        assertIs<JobUiState.NewJob>(state)
        // The accept is HELD in-flight after the 2xx (spinner on, both buttons disabled) — it clears only
        // when the job advances off New (see accept_holdsSubmittingSpinner_untilJobLeavesNew_thenClears).
        // newJobSource never advances, so it stays submitting; and no success toast (the transition is the
        // confirmation, not a toast).
        assertTrue(state.isSubmitting)
        assertEquals(JobSubmitAction.Accept, state.submittingAction)
        assertNull(state.errorMessage)
        assertNull(state.successMessage)
    }

    @Test
    fun accept_failure_setsGenericError_andDoesNotRefresh() = runTest {
        val actions = FakeJobActionRepository(acceptError = JobActionError.Generic)
        val source = newJobSource()
        val vm = viewModel(source, actions = actions)

        vm.onIntent(JobUiIntent.Accept)

        val state = vm.uiState.value
        assertIs<JobUiState.NewJob>(state)
        assertEquals(JobMessage.Generic, state.errorMessage)
        assertFalse(state.isSubmitting)
        assertEquals(0, source.refreshCount)
    }

    @Test
    fun accept_failure_409_setsReassignedMessage() = runTest {
        val vm = viewModel(newJobSource(), actions = FakeJobActionRepository(acceptError = JobActionError.Reassigned))

        vm.onIntent(JobUiIntent.Accept)

        val state = vm.uiState.value
        assertIs<JobUiState.NewJob>(state)
        assertEquals(JobMessage.Reassigned, state.errorMessage)
    }

    @Test
    fun accept_failure_serverMessage_isSurfacedVerbatim() = runTest {
        // ECPO #8: a parsed server CustomError message is shown as-is (not the hardcoded copy).
        val actions = FakeJobActionRepository(acceptError = JobActionError.Server("Reassigned by ops."))
        val vm = viewModel(newJobSource(), actions = actions)

        vm.onIntent(JobUiIntent.Accept)

        val state = vm.uiState.value
        assertIs<JobUiState.NewJob>(state)
        assertEquals(JobMessage.Server("Reassigned by ops."), state.errorMessage)
    }

    @Test
    fun accept_holdsSubmittingSpinner_untilJobLeavesNew_thenClears() = runTest {
        // ECPO: the Accept spinner (and the Deny-disabled guard) must persist from press until the
        // accepted job actually advances off New — not just for the (fast) POST — then clear. Covers the
        // gap where the MQTT/poll state advance lags the 2xx by seconds.
        val store = JobActionStore()
        val source = FakeRunnerStateSource(envelope(JobWidgetName.NEW_JOB, """{"job_id":739}"""))
        val vm = viewModel(source, actions = FakeJobActionRepository(), actionStore = store)

        vm.onIntent(JobUiIntent.Accept)
        advanceUntilIdle()
        // Still New (backend hasn't advanced) → held in-flight: spinner on, both buttons disabled.
        val accepting = vm.uiState.value
        assertIs<JobUiState.NewJob>(accepting)
        assertEquals(JobSubmitAction.Accept, accepting.submittingAction)
        assertTrue(accepting.isSubmitting)

        // The accepted job advances off New (check-in arrives) → the held state clears on the transition.
        source.emit(envelope(JobWidgetName.CHECK_IN, """{"job_id":739}"""))
        advanceUntilIdle()
        assertIs<JobUiState.AwaitingCheckIn>(vm.uiState.value)
        assertNull(store.state.value.submitting)
    }

    @Test
    fun accept_reportsResolved_whenJobLeavesNew() = runTest {
        // The healthy path. `accept_job_button_clicked` fires regardless of outcome and carries no
        // latency, so this is the only event that can say the accept actually completed and how long
        // the runner waited for it.
        val tracker = FakeAnalyticsTracker()
        val source = FakeRunnerStateSource(envelope(JobWidgetName.NEW_JOB, """{"job_id":739}"""))
        val vm = viewModel(source, actions = FakeJobActionRepository(), analytics = JobAnalytics(tracker))

        vm.onIntent(JobUiIntent.Accept)
        // runCurrent, NOT advanceUntilIdle: the latter fast-forwards virtual time past the watchdog
        // delay, so the timeout would fire before the transition ever gets a chance to land.
        runCurrent()
        assertTrue(
            tracker.events.none { it.name == "job_accept_resolved" },
            "still spinning — nothing has resolved yet",
        )

        source.emit(envelope(JobWidgetName.CHECK_IN, """{"job_id":739}"""))
        advanceUntilIdle()

        // `single` also proves the watchdog was cancelled — a surviving timer would double-report.
        val resolved = tracker.events.single { it.name == "job_accept_resolved" }
        assertEquals("state_transition", resolved.props["resolved_by"])
        assertEquals(739, resolved.props["job_id"], "stamped with the job it belongs to")
        assertNotNull(resolved.props["ms_since_tap"])
    }

    @Test
    fun accept_onOneSurface_isReportedByTheSurfaceThatSeesTheTransition() = runTest {
        // The overlay accepts, then opens the app; the in-app ViewModel is created afterwards and is
        // the one that observes the job leaving New. With the tap time held per-ViewModel it was null
        // there, so the healthy-path event went missing in precisely the cross-surface flow the
        // shared JobActionStore exists to support.
        // Both surfaces share ONE JobAnalytics in production (Koin single) and both observe the same
        // state stream, so which of them wins the race to resolve is not deterministic — and must not
        // matter. What matters: exactly one event, and it carries a real elapsed time.
        val tracker = FakeAnalyticsTracker()
        val analytics = JobAnalytics(tracker)
        val store = JobActionStore()
        val source = FakeRunnerStateSource(envelope(JobWidgetName.NEW_JOB, """{"job_id":739}"""))
        val overlayVm = viewModel(
            source,
            actions = FakeJobActionRepository(),
            actionStore = store,
            analytics = analytics,
        )

        overlayVm.onIntent(JobUiIntent.Accept)
        runCurrent()

        // The app opens: a second ViewModel over the SAME store, source and analytics, as the hosts do.
        val inAppVm = viewModel(
            source,
            actions = FakeJobActionRepository(),
            actionStore = store,
            analytics = analytics,
        )
        runCurrent()
        source.emit(envelope(JobWidgetName.CHECK_IN, """{"job_id":739}"""))
        advanceUntilIdle()

        assertIs<JobUiState.AwaitingCheckIn>(inAppVm.uiState.value)
        // `single` is the assertion that matters twice over: the event is not lost when the resolving
        // surface isn't the submitting one, and the two surfaces don't both report it.
        val resolved = tracker.events.single { it.name == "job_accept_resolved" }
        assertEquals("state_transition", resolved.props["resolved_by"])
        assertNotNull(resolved.props["ms_since_tap"])
    }

    @Test
    fun accept_whenHostScopeIsCancelledMidFlight_settlesTheSharedStore() = runTest {
        // REGRESSION GUARD for the field failure (runner 4500487, 2026-08-12): Accept tapped, spinner
        // never resolved, no completion event, no error, and every later accept silently dropped.
        //
        // Two defects combined. The in-app host passed `rememberCoroutineScope()` as `appScope`
        // (ActiveJobOverlay.kt), which Compose cancels when the overlay leaves composition — despite
        // appScope's contract requiring a process-lived scope. And `submit()` didn't handle
        // cancellation, so a cancel between beginSubmit() and the response stranded the SHARED,
        // process-lived JobActionStore `submitting` with nothing alive to settle it.
        //
        // The host now injects the process-lived JobActionScope, so this cancellation cannot happen
        // in production; this asserts the second line of defence — if anything ever does cancel a
        // submit, the shared store must not be left wedged.
        val tracker = FakeAnalyticsTracker()
        val store = JobActionStore()
        val actions = FakeJobActionRepository().apply { acceptGate = CompletableDeferred() }
        val hostScope = CoroutineScope(UnconfinedTestDispatcher(testScheduler))
        val vm = JobViewModel(
            source = FakeRunnerStateSource(envelope(JobWidgetName.NEW_JOB, """{"job_id":739}""")),
            actions = actions,
            location = FakeLocationProvider(),
            clock = FakeJobClock(),
            blockListDataSource = FakeBlockListRepository(),
            preferenceStorage = InMemoryPreferenceStorage(),
            appScope = hostScope,
            analytics = JobAnalytics(tracker),
            actionStore = store,
        )

        vm.onIntent(JobUiIntent.Accept)
        runCurrent()
        assertEquals(1, actions.acceptCalls.size, "the POST went out and is still in flight")
        assertEquals(JobSubmitAction.Accept, store.state.value.submitting)

        // The host leaves composition — rotation, KMP↔Flutter handoff, Activity recreation.
        hostScope.cancel()
        advanceUntilIdle()

        // The shared store must be settled, so a freshly composed New-Job card shows a LIVE Accept
        // button rather than a spinner nothing can clear.
        assertNull(
            store.state.value.submitting,
            "the shared store must never be left wedged by a cancellation",
        )

        // And a different job's accept must go through — the guard is per-job, so a stale entry
        // cannot silently block every future accept (the "can't accept jobs" complaint).
        val laterVm = JobViewModel(
            source = FakeRunnerStateSource(envelope(JobWidgetName.NEW_JOB, """{"job_id":740}""")),
            actions = FakeJobActionRepository(),
            location = FakeLocationProvider(),
            clock = FakeJobClock(),
            blockListDataSource = FakeBlockListRepository(),
            preferenceStorage = InMemoryPreferenceStorage(),
            appScope = CoroutineScope(UnconfinedTestDispatcher(testScheduler)),
            analytics = JobAnalytics(tracker),
            actionStore = store,
        )
        laterVm.onIntent(JobUiIntent.Accept)
        advanceUntilIdle()
        assertEquals(740, store.state.value.jobId, "the next job's accept was accepted, not dropped")
    }

    @Test
    fun accept_staleInFlightForAnotherJob_doesNotBlockTheCurrentOne() = runTest {
        // The submit guard used to be global (`if (actionStore.isSubmitting) return`), so one stuck
        // action dropped every later accept for every job. Now keyed per job.
        val store = JobActionStore()
        store.beginSubmit(jobId = 111, action = JobSubmitAction.Accept, startedAtMs = 0L)
        val actions = FakeJobActionRepository()
        val vm = viewModel(newJobSource(), actions = actions, actionStore = store)

        vm.onIntent(JobUiIntent.Accept)
        advanceUntilIdle()

        assertEquals(listOf(739), actions.acceptCalls.map { it.first })
    }

    @Test
    fun accept_lateResultForASupersededJob_doesNotClobberTheNewJobsSubmit() = runTest {
        // The per-job guard deliberately lets job B submit while job A's POST is still in flight
        // (A stuck on a slow network, deallocated, B offered). A's LATE result must then settle
        // nothing: blindly calling failed() killed B's live spinner mid-flight, pinned A's error
        // toast on B's card, and re-enabled B's buttons — a double-submit window. (Release never
        // hit this: its global guard serialized submits; the per-job guard created the overlap.)
        val store = JobActionStore()
        val actions = FakeJobActionRepository()
        val tracker = FakeAnalyticsTracker()
        val source = newJobSource() // job 739 = A
        val vm = viewModel(source, actions = actions, actionStore = store, analytics = JobAnalytics(tracker))

        val gateA = CompletableDeferred<Unit>()
        actions.acceptGate = gateA
        vm.onIntent(JobUiIntent.Accept); runCurrent() // A in flight, suspended on gateA

        // A is deallocated; job 812 = B is offered and accepted while A's POST is still out.
        source.emit(envelope(JobWidgetName.NEW_JOB, NEW_JOB_JSON.replace("\"job_id\": 739", "\"job_id\": 812")))
        runCurrent()
        val gateB = CompletableDeferred<Unit>()
        actions.acceptGate = gateB
        vm.onIntent(JobUiIntent.Accept); runCurrent() // B in flight, suspended on gateB
        assertEquals(listOf(739, 812), actions.acceptCalls.map { it.first })

        actions.acceptError = JobActionError.Generic
        gateA.complete(Unit) // A's POST fails, late
        advanceUntilIdle()

        val s = store.state.value
        assertEquals(812, s.jobId, "the store still belongs to B")
        assertEquals(JobSubmitAction.Accept, s.submitting, "B's spinner survives A's late failure")
        assertEquals(null, s.errorMessage, "A's failure toast must not land on B's card")
        assertTrue(
            tracker.events.none { it.name == "error_screen_load" },
            "and no 'surface shown' event for a toast that was never rendered",
        )
        assertEquals(
            739,
            tracker.events.single { it.name == "job_accept_resolved" }.props["job_id"],
            "A's outcome is still reported, filed under A — not under B, who now owns the ambient id",
        )

        actions.acceptError = null
        gateB.complete(Unit)
        advanceUntilIdle() // B resolves normally (2xx → hold), nothing left hanging
    }

    @Test
    fun accept_handoffWhereTheTransitionLandedFirst_stillResolves() = runTest {
        // The overlay accepts, opens the app and is dismissed. If the transition lands BEFORE the
        // in-app ViewModel is constructed, that VM's first envelope is already CheckIn — so the
        // observed-transition branch (`previous != offered`) can never fire, since offeredJobId
        // starts null. Verified before the fix: the shared store stayed on submitting=Accept and no
        // resolution was emitted, leaving the appScope watchdog to report RESOLVED_BY_TIMEOUT ~10s
        // later for an accept that had already succeeded.
        val tracker = FakeAnalyticsTracker()
        val store = JobActionStore()
        store.beginSubmit(739, JobSubmitAction.Accept, startedAtMs = 0L)
        store.acceptAcknowledged(0L) // the 2xx already came back on the other surface

        val source = FakeRunnerStateSource(envelope(JobWidgetName.CHECK_IN, """{"job_id":739}"""))
        viewModel(source, actionStore = store, analytics = JobAnalytics(tracker))
        advanceUntilIdle()

        assertNull(store.state.value.submitting, "the store must not be left mid-accept")
        val resolved = tracker.events.single { it.name == "job_accept_resolved" }
        assertEquals("state_transition", resolved.props["resolved_by"], "healthy, not a timeout")
        assertEquals(739, resolved.props["job_id"])
    }

    @Test
    fun accept_stillInFlightOnAnotherSurface_isNotSettledByAFreshVm() = runTest {
        // The other side of the same guard: with the POST still outstanding (no acceptedAtMs), the
        // submitting coroutine owns the settle. A fresh VM must not resolve it early — doing so
        // would re-open the double-submit window and file a healthy resolution for a call that
        // might still fail.
        val tracker = FakeAnalyticsTracker()
        val store = JobActionStore()
        store.beginSubmit(739, JobSubmitAction.Accept, startedAtMs = 0L) // no acceptAcknowledged

        val source = FakeRunnerStateSource(envelope(JobWidgetName.CHECK_IN, """{"job_id":739}"""))
        viewModel(source, actionStore = store, analytics = JobAnalytics(tracker))
        advanceUntilIdle()

        assertEquals(JobSubmitAction.Accept, store.state.value.submitting, "the POST still owns it")
        assertTrue(tracker.events.none { it.name == "job_accept_resolved" })
    }

    @Test
    fun accept_offerWithdrawnWhilePostInFlight_reportsOnlyTheApiError() = runTest {
        // `submitting` is set BEFORE the POST, so the state-transition branch used to fire for an
        // accept that had not returned yet: the offer lapsing mid-call emitted
        // job_accept_resolved(state_transition) with a short ms_since_tap — a FAILED accept in the
        // healthy bucket, deflating the latency distribution for exactly the slow accepts this
        // instrumentation exists to measure — and then a SECOND event when the POST failed.
        // Only a 2xx (JobActionUiState.acceptedAtMs) may now claim the healthy resolution.
        val tracker = FakeAnalyticsTracker()
        val actions = FakeJobActionRepository().apply { acceptGate = CompletableDeferred() }
        val source = FakeRunnerStateSource(envelope(JobWidgetName.NEW_JOB, """{"job_id":739}"""))
        val vm = viewModel(source, actions = actions, analytics = JobAnalytics(tracker))

        vm.onIntent(JobUiIntent.Accept); runCurrent() // POST in flight, no 2xx yet
        source.emit(envelope(JobWidgetName.CHECK_IN, """{"job_id":739}""")) // offer gone mid-call
        runCurrent()
        assertTrue(
            tracker.events.none { it.name == "job_accept_resolved" },
            "no resolution may be claimed while the POST is still in flight",
        )

        actions.acceptError = JobActionError.Generic
        actions.acceptGate?.complete(Unit)
        advanceUntilIdle()

        val resolved = tracker.events.single { it.name == "job_accept_resolved" }
        assertEquals(
            "api_error",
            resolved.props["resolved_by"],
            "one accept ⇒ one resolution, and it is the real outcome",
        )
    }

    @Test
    fun accept_doubleTapOnTheSameJob_stillSubmitsOnce() = runTest {
        val actions = FakeJobActionRepository().apply { acceptGate = CompletableDeferred() }
        val vm = viewModel(newJobSource(), actions = actions)

        vm.onIntent(JobUiIntent.Accept)
        runCurrent()
        vm.onIntent(JobUiIntent.Accept) // re-tap while in flight
        runCurrent()

        assertEquals(1, actions.acceptCalls.size, "the per-job guard still blocks a double submit")
        actions.acceptGate?.complete(Unit)
        advanceUntilIdle()
    }

    @Test
    fun accept_reportsTimeout_whenTransitionNeverArrives_withoutClearingSpinner() = runTest {
        // The wedge candidate: the POST succeeded but no envelope ever moved the job off New. This
        // change REPORTS that and deliberately leaves the UI exactly as it was — whether to also
        // break out of the spinner is the decision this event exists to inform.
        val tracker = FakeAnalyticsTracker()
        val store = JobActionStore()
        val source = FakeRunnerStateSource(envelope(JobWidgetName.NEW_JOB, """{"job_id":739}"""))
        val vm = viewModel(
            source,
            actions = FakeJobActionRepository(),
            actionStore = store,
            analytics = JobAnalytics(tracker),
        )

        vm.onIntent(JobUiIntent.Accept)
        advanceUntilIdle()

        val resolved = tracker.events.single { it.name == "job_accept_resolved" }
        assertEquals("timeout", resolved.props["resolved_by"])
        assertEquals(
            JobSubmitAction.Accept,
            store.state.value.submitting,
            "reporting only — the in-flight state is untouched",
        )
    }

    @Test
    fun accept_transportFailure_reportsNetworkError() = runTest {
        // `is_network_error` was hardcoded false on the error surface, so "no internet" and "the
        // backend rejected this" were the same bucket. Both events now carry the truth.
        val tracker = FakeAnalyticsTracker()
        val actions = FakeJobActionRepository(acceptError = JobActionError.Network(AppErrorType.NO_INTERNET))
        val vm = viewModel(newJobSource(), actions = actions, analytics = JobAnalytics(tracker))

        vm.onIntent(JobUiIntent.Accept)
        advanceUntilIdle()

        val resolved = tracker.events.single { it.name == "job_accept_resolved" }
        assertEquals("api_error", resolved.props["resolved_by"])
        assertEquals("network", resolved.props["error_kind"])
        assertEquals(true, resolved.props["is_network_error"])
        assertEquals(true, tracker.events.single { it.name == "error_screen_load" }.props["is_network_error"])
    }

    @Test
    fun accept_reassigned409_isReportedAsBenignRace_notANetworkError() = runTest {
        // A 409 is an expected race, not a failure to chase. It has to be separable in the numbers.
        val tracker = FakeAnalyticsTracker()
        val actions = FakeJobActionRepository(acceptError = JobActionError.Reassigned)
        val vm = viewModel(newJobSource(), actions = actions, analytics = JobAnalytics(tracker))

        vm.onIntent(JobUiIntent.Accept)
        advanceUntilIdle()

        val resolved = tracker.events.single { it.name == "job_accept_resolved" }
        assertEquals("reassigned", resolved.props["error_kind"])
        assertEquals(false, resolved.props["is_network_error"])
    }

    @Test
    fun deny_callsDeny_noRefresh() = runTest {
        val actions = FakeJobActionRepository()
        val source = newJobSource()
        val vm = viewModel(source, actions = actions)

        vm.onIntent(JobUiIntent.Deny)
        advanceUntilIdle()

        assertEquals(listOf(739), actions.denyCalls.map { it.first })
        // WS5: stage advance arrives via MQTT — no EAGER current_state refresh.
        // Feature #4: deny arms the TIMED fallback instead.
        assertEquals(0, source.refreshCount)
        assertEquals(listOf("job_deny"), source.postActions)
        assertEquals(JobMessage.JobDenied, (vm.uiState.value as JobUiState.NewJob).successMessage)
    }

    @Test
    fun successShown_clearsSuccess() = runTest {
        val source = newJobSource()
        val vm = viewModel(source)

        // Deny surfaces a success toast to clear (Accept no longer does — it holds the spinner through to
        // the check-in transition instead of showing an "accepted" toast).
        vm.onIntent(JobUiIntent.Deny)
        advanceUntilIdle()
        assertEquals(JobMessage.JobDenied, (vm.uiState.value as JobUiState.NewJob).successMessage)

        vm.onIntent(JobUiIntent.SuccessShown)
        assertNull((vm.uiState.value as JobUiState.NewJob).successMessage)
    }

    @Test
    fun action_whenNotInJobFlow_isNoOp() = runTest {
        val actions = FakeJobActionRepository()
        val source = FakeRunnerStateSource(envelope("RUNNER_LOGOUT", "{}"))
        val vm = viewModel(source, actions = actions)

        vm.onIntent(JobUiIntent.Accept)

        assertTrue(actions.acceptCalls.isEmpty())
        assertEquals(0, source.refreshCount)
    }

    // ── Cross-surface shared action store (ECPO issue #1) ─────────────────────
    // The overlay and the in-app screen build separate JobViewModels but share ONE process-lived
    // JobActionStore, so an accept begun on the overlay stays in-flight (and guarded) on the
    // JobActivity it opens; settled state is keyed by job so it can't bleed onto a different card.

    @Test
    fun newJob_reflectsInFlightAccept_fromSharedStore_andBlocksReSubmit() = runTest {
        // The overlay begins an accept for job 739 on the shared store; the in-app VM (built later)
        // renders it as in-flight (Accept loading) and its own Accept must be a no-op (no double POST).
        val store = JobActionStore()
        store.beginSubmit(739, JobSubmitAction.Accept)
        val activityActions = FakeJobActionRepository()
        val activityVm = viewModel(newJobSource(), actions = activityActions, actionStore = store)

        val state = activityVm.uiState.value
        assertIs<JobUiState.NewJob>(state)
        assertTrue(state.isSubmitting)
        assertEquals(JobSubmitAction.Accept, state.submittingAction)

        activityVm.onIntent(JobUiIntent.Accept)
        advanceUntilIdle()
        assertTrue(activityActions.acceptCalls.isEmpty()) // guard blocked the second accept_job
    }

    @Test
    fun newJob_inFlightDeny_marksDenyAction_notAccept() = runTest {
        // Regression (deny-button loading): a deny in flight must mark the DENY action so the footer /
        // deny sheet spin the Deny button — NOT the Accept button (the single-flag bug). Both buttons
        // are still blocked (isSubmitting true) so Accept can't be tapped mid-deny.
        val store = JobActionStore()
        store.beginSubmit(739, JobSubmitAction.Deny)
        val vm = viewModel(newJobSource(), actionStore = store)

        val state = vm.uiState.value
        assertIs<JobUiState.NewJob>(state)
        assertEquals(JobSubmitAction.Deny, state.submittingAction)
        assertTrue(state.isSubmitting)
    }

    @Test
    fun newJob_acceptStaysInFlightAcrossSurfaces_afterThe2xx() = runTest {
        // An accept begun on one surface (the overlay) is visible as in-flight on the other (same job
        // 739) — and STAYS in-flight past the 2xx, since the accept holds the spinner until the job
        // advances off New. Both surfaces share the one process-lived store.
        val store = JobActionStore()
        val overlayVm = viewModel(newJobSource(), actionStore = store)
        val activityVm = viewModel(newJobSource(), actionStore = store)

        overlayVm.onIntent(JobUiIntent.Accept)
        advanceUntilIdle()

        val activityState = activityVm.uiState.value
        assertIs<JobUiState.NewJob>(activityState)
        assertEquals(JobSubmitAction.Accept, activityState.submittingAction)
        assertTrue(activityState.isSubmitting)
    }

    @Test
    fun newJob_ignoresSettledActionFromADifferentJob() = runTest {
        // A settled toast on the shared store (job 739) must NOT bleed onto a different job's card.
        val store = JobActionStore()
        viewModel(newJobSource(), actionStore = store).onIntent(JobUiIntent.Accept)
        advanceUntilIdle()

        val other = viewModel(
            FakeRunnerStateSource(envelope(JobWidgetName.NEW_JOB, """{"job_id":800}""")),
            actionStore = store,
        )
        val state = other.uiState.value
        assertIs<JobUiState.NewJob>(state)
        assertNull(state.successMessage)
        assertFalse(state.isSubmitting)
    }

    // ── Completed → block flow ──

    @Test
    fun completed_openBlockFlow_createsBlockSheetVm() = runTest {
        val vm = viewModel(FakeRunnerStateSource(envelope(JobWidgetName.POST_CHECKOUT, POST_CHECKOUT_JSON)))
        assertIs<JobUiState.Completed>(vm.uiState.value)
        assertNull(vm.blockCustomer.value)

        vm.onIntent(JobUiIntent.OpenBlockFlow)

        assertNotNull(vm.blockCustomer.value)
    }

    @Test
    fun completed_customerBlocked_flagsJob_emitsToast_andClosesSheet() = runTest {
        val vm = viewModel(FakeRunnerStateSource(envelope(JobWidgetName.POST_CHECKOUT, POST_CHECKOUT_JSON)))
        vm.onIntent(JobUiIntent.OpenBlockFlow)
        var toasted = false
        val collector = launch { vm.blockedToast.collect { toasted = true } }

        vm.onIntent(JobUiIntent.CustomerBlocked)
        advanceUntilIdle()

        assertEquals(739, vm.blockedForJobId.value)
        assertTrue(toasted)
        assertNull(vm.blockCustomer.value)
        collector.cancel()
    }

    @Test
    fun completed_unblockCustomer_callsUnblock_andClearsFlag() = runTest {
        val blockDs = FakeBlockListRepository()
        val vm = viewModel(
            FakeRunnerStateSource(envelope(JobWidgetName.POST_CHECKOUT, POST_CHECKOUT_JSON)),
            blockListDataSource = blockDs,
        )
        vm.onIntent(JobUiIntent.CustomerBlocked)
        assertEquals(739, vm.blockedForJobId.value)

        vm.onIntent(JobUiIntent.UnblockCustomer)
        advanceUntilIdle()

        assertEquals(listOf<Pair<Int, Int?>>(42 to 739), blockDs.unblockCalls)
        assertNull(vm.blockedForJobId.value)
    }

    @Test
    fun dismissHouseTasks_closesTheShowOnceGate() = runTest {
        // The forced house-tasks sheet is gated open on POST_CHECKOUT (not yet submitted). When its
        // fetch errors the screen makes it dismissible; dismissing fires DismissHouseTasks, which closes
        // the gate in memory so the Completed screen underneath is reachable.
        val vm = viewModel(FakeRunnerStateSource(envelope(JobWidgetName.POST_CHECKOUT, POST_CHECKOUT_JSON)))
        advanceUntilIdle()
        assertEquals(739, vm.tasksSheetForJob.value)

        vm.onIntent(JobUiIntent.DismissHouseTasks(739))
        advanceUntilIdle()

        assertNull(vm.tasksSheetForJob.value)
    }

    @Test
    fun errorShown_clearsError() = runTest {
        val actions = FakeJobActionRepository(acceptError = JobActionError.Generic)
        val vm = viewModel(newJobSource(), actions = actions)
        vm.onIntent(JobUiIntent.Accept)
        assertEquals(JobMessage.Generic, (vm.uiState.value as JobUiState.NewJob).errorMessage)

        vm.onIntent(JobUiIntent.ErrorShown)

        assertNull((vm.uiState.value as JobUiState.NewJob).errorMessage)
    }

    @Test
    fun refresh_asksSourceToRefresh() = runTest {
        val source = newJobSource()
        viewModel(source).onIntent(JobUiIntent.Refresh)
        assertEquals(1, source.refreshCount)
    }

    @Test
    fun requestDenyFlow_flagsCurrentJob_andDoesNotDeny_thenDenyFlowShownClears() = runTest {
        // ECPO-860 #3: the draw-over-apps overlay's Deny must NOT hit deny_job — it opens the app and
        // asks the in-app screen to show the deny sheet, via this shared request. NEW_JOB_JSON's job_id.
        val actions = FakeJobActionRepository()
        val vm = viewModel(newJobSource(), actions = actions)
        advanceUntilIdle()
        assertNull(vm.denyFlowRequestedForJob.value)

        vm.onIntent(JobUiIntent.RequestDenyFlow)
        advanceUntilIdle()
        assertEquals(739, vm.denyFlowRequestedForJob.value)
        // Crucially, no deny_job call was made — the deny only fires later from the sheet's CTA.
        assertTrue(actions.denyCalls.isEmpty())

        vm.onIntent(JobUiIntent.DenyFlowShown)
        assertNull(vm.denyFlowRequestedForJob.value)
    }

    @Test
    fun newJob_computesAcceptCountdown_fromNotifiedAtAndTimer() = runTest {
        val notified = "2026-06-27T10:00:00+05:30"
        // notified at 1_000_000 ms, now is 30s later, 120s window → 90s remaining.
        val clock = FakeJobClock(now = 1_030_000L, parsed = mapOf(notified to 1_000_000L))
        val json = """{"job_id":1,"timer_duration":120,"notified_at":"$notified"}"""
        val vm = viewModel(FakeRunnerStateSource(envelope(JobWidgetName.NEW_JOB, json)), clock = clock)

        val state = vm.uiState.value
        assertIs<JobUiState.NewJob>(state)
        assertEquals(120, state.acceptTotalSeconds)
        assertEquals(90, state.acceptRemainingSeconds)
    }

    @Test
    fun newJob_unparseableNotifiedAt_fallsBackToMountRelative() = runTest {
        // No mapping for notified_at → start = now → full window remains.
        val clock = FakeJobClock(now = 5_000L)
        val vm = viewModel(newJobSource(), clock = clock)

        val state = vm.uiState.value
        assertIs<JobUiState.NewJob>(state)
        assertEquals(state.acceptTotalSeconds, state.acceptRemainingSeconds)
        assertEquals(120, state.acceptTotalSeconds)
    }

    @Test
    fun newJob_acceptCountdown_resumesFromPersistedDeadline_afterRelaunch() = runTest {
        // The offer's ABSOLUTE deadline is persisted on first sight; a relaunch that re-stamps
        // notified_at to "now" must NOT restart the countdown — it re-anchors to the stored deadline.
        val storage = InMemoryPreferenceStorage()
        val notified1 = "2026-06-27T10:00:00+05:30"
        val notified2 = "2026-06-27T10:00:30+05:30" // backend re-stamped it 30s later on the re-poll

        // First sight: now == notified1 (t=1_000_000), 120s window → persists deadline 1_120_000.
        val vm1 = viewModel(
            FakeRunnerStateSource(
                envelope(JobWidgetName.NEW_JOB, """{"job_id":1,"timer_duration":120,"notified_at":"$notified1"}"""),
            ),
            clock = FakeJobClock(now = 1_000_000L, parsed = mapOf(notified1 to 1_000_000L)),
            preferenceStorage = storage,
        )
        advanceUntilIdle()
        assertEquals(120, (vm1.uiState.value as JobUiState.NewJob).acceptRemainingSeconds)

        // Relaunch 30s later with a RE-STAMPED notified_at + a fresh in-memory cache. Without persistence
        // this would reset to 120; with it, the stored deadline (1_120_000) wins → 90s remaining.
        val vm2 = viewModel(
            FakeRunnerStateSource(
                envelope(JobWidgetName.NEW_JOB, """{"job_id":1,"timer_duration":120,"notified_at":"$notified2"}"""),
            ),
            clock = FakeJobClock(now = 1_030_000L, parsed = mapOf(notified2 to 1_030_000L)),
            preferenceStorage = storage,
        )
        advanceUntilIdle()
        assertEquals(90, (vm2.uiState.value as JobUiState.NewJob).acceptRemainingSeconds)
    }

    @Test
    fun newJob_reassignedAfterDeallocation_restartsAcceptCountdownFresh() = runTest {
        // ECPO-860: a job offered, then deallocated to another runner (the offer leaves the screen), then
        // reassigned to the SAME runner must show a FRESH countdown — not resume the previous assignment's
        // remaining time. Same VM instance (the app stayed alive), so the deallocation transition is
        // observed; unlike a cold relaunch (above), the stale deadline must NOT be resumed.
        val storage = InMemoryPreferenceStorage()
        val notified1 = "2026-06-27T10:00:00+05:30"
        val notified2 = "2026-06-27T10:03:00+05:30" // reassigned 3 min later → a genuinely new allocation
        val source = FakeRunnerStateSource(
            envelope(JobWidgetName.NEW_JOB, """{"job_id":1,"timer_duration":120,"notified_at":"$notified1"}"""),
        )
        // now == notified2 (t=1_180_000, 180s after notified1) → the first offer's 120s window has fully
        // elapsed; the reassignment's window is full. Resuming the stale deadline would show 0s remaining.
        val vm = viewModel(
            source,
            clock = FakeJobClock(now = 1_180_000L, parsed = mapOf(notified1 to 1_000_000L, notified2 to 1_180_000L)),
            preferenceStorage = storage,
        )
        advanceUntilIdle()

        // Deallocated → the runner's state leaves the New offer (a non-JOB widget → NotInJobFlow).
        source.emit(envelope("RUNNER_HOME", "{}"))
        advanceUntilIdle()
        assertIs<JobUiState.NotInJobFlow>(vm.uiState.value)

        // Reassigned to the same runner with a fresh notified_at → the countdown must restart at full 120s.
        source.emit(envelope(JobWidgetName.NEW_JOB, """{"job_id":1,"timer_duration":120,"notified_at":"$notified2"}"""))
        advanceUntilIdle()

        val state = vm.uiState.value
        assertIs<JobUiState.NewJob>(state)
        assertEquals(120, state.acceptTotalSeconds)
        assertEquals(120, state.acceptRemainingSeconds) // fresh — not the elapsed (0s) previous window
    }

    @Test
    fun newEnvelope_advancesLifecycle() = runTest {
        val source = newJobSource()
        val vm = viewModel(source)
        assertIs<JobUiState.NewJob>(vm.uiState.value)

        source.emit(envelope(JobWidgetName.POST_ACCEPT, """{"job_id":739}"""))

        assertEquals(JobUiState.AwaitingCheckIn(739), vm.uiState.value)
    }

    @Test
    fun awaitingCheckIn_mapsAllowNoOtpFlag() = runTest {
        val source = FakeRunnerStateSource(
            envelope(JobWidgetName.CHECK_IN, """{"job_id":739,"allow_check_in_without_otp":true}"""),
        )
        val state = viewModel(source).uiState.value
        assertIs<JobUiState.AwaitingCheckIn>(state)
        assertTrue(state.allowNoOtp)
    }

    @Test
    fun awaitingCheckIn_dedupesCheckInBonusFromBreakdown() = runTest {
        // Payload carries the check-in bonus BOTH as a `check_in_bonus` breakdown line AND as
        // check_in_amount. The mapper drops the breakdown line so the earnings accordion renders it
        // once (the derived "Check In by <time>" row), not twice.
        val json = """
            {"job_id":739,"payout_info":{"total_earning":450,"check_in_amount":50,
             "check_in_time":"7:45 PM",
             "breakdown":[
               {"title":{"key":"base_pay","default_text":"Base pay"},"amount":400},
               {"title":{"key":"check_in_bonus","default_text":"Check-in bonus"},"pill_text":"Extra","amount":50}
             ]}}
        """.trimIndent()
        val state = viewModel(FakeRunnerStateSource(envelope(JobWidgetName.CHECK_IN, json))).uiState.value
        assertIs<JobUiState.AwaitingCheckIn>(state)
        assertEquals(50, state.payout?.checkInAmount)
        // Only the generic base_pay line remains; the check_in_bonus line is deduped out.
        assertEquals(listOf("base_pay"), state.payout?.lines?.map { it.labelKey })
    }

    @Test
    fun awaitingCheckIn_keepsCheckInBonusLine_whenNoCheckInAmount() = runTest {
        // No check_in_amount → no derived row, so the breakdown check_in_bonus line is the sole
        // representation and is kept (dedup only fires when a derived row will supersede it).
        val json = """
            {"job_id":739,"payout_info":{"total_earning":450,
             "breakdown":[
               {"title":{"key":"base_pay","default_text":"Base pay"},"amount":400},
               {"title":{"key":"check_in_bonus","default_text":"Check-in bonus"},"amount":50}
             ]}}
        """.trimIndent()
        val state = viewModel(FakeRunnerStateSource(envelope(JobWidgetName.CHECK_IN, json))).uiState.value
        assertIs<JobUiState.AwaitingCheckIn>(state)
        assertEquals(listOf("base_pay", "check_in_bonus"), state.payout?.lines?.map { it.labelKey })
    }

    @Test
    fun payoutBreakdown_parsesPillIconAndSubtitle() = runTest {
        // Flutter `_PayoutRow` parity: a breakdown line can carry a duration pill (`pill_text`),
        // a server icon (`icon_url`) and a subtitle (`subtitle.default_text`) — all optional, so a
        // line without them parses to nulls (and renders as before).
        val json = """
            {"job_id":739,"payout_info":{"total_earning":145,
             "breakdown":[
               {"title":{"key":"work","default_text":"Work"},"pill_text":"1 hr","amount":120},
               {"title":{"key":"monsoon_bonus","default_text":"Monsoon Bonus"},
                "pill_text":"1 hr","icon_url":"https://cdn.snabbit.com/rain.png",
                "subtitle":{"key":"bonus_note","default_text":"₹10 + ₹25 Extra"},"amount":10}
             ]}}
        """.trimIndent()
        val state = viewModel(FakeRunnerStateSource(envelope(JobWidgetName.CHECK_IN, json))).uiState.value
        assertIs<JobUiState.AwaitingCheckIn>(state)
        val lines = state.payout?.lines.orEmpty()
        assertEquals(2, lines.size)
        // First line: pill only; icon/subtitle absent → null.
        assertEquals("1 hr", lines[0].pillText)
        assertNull(lines[0].iconUrl)
        assertNull(lines[0].subtitle)
        // Second line (monsoon bonus): pill + server icon + subtitle all parsed.
        assertEquals("1 hr", lines[1].pillText)
        assertEquals("https://cdn.snabbit.com/rain.png", lines[1].iconUrl)
        assertEquals("₹10 + ₹25 Extra", lines[1].subtitle)
    }

    @Test
    fun awaitingCheckIn_mapsScreenData() = runTest {
        val json = """
            {"job_id":739,"customer_name":"Radhika S","address":"HAL Old Airport rd",
             "payout_info":{"total_earning":150,"check_in_amount":5,"check_in_time":"7:45 PM"}}
        """.trimIndent()
        val state = viewModel(FakeRunnerStateSource(envelope(JobWidgetName.CHECK_IN, json))).uiState.value
        assertIs<JobUiState.AwaitingCheckIn>(state)
        assertEquals("Radhika S", state.customerName)
        assertEquals("HAL Old Airport rd", state.address)
        assertEquals(150, state.payout?.totalEarning)
        assertEquals(5, state.payout?.checkInAmount)
    }

    @Test
    fun awaitingCheckIn_beforeDeadline_isEligible_withCountdown() = runTest {
        // Deadline 00:10 IST → today at startOfDay(0) + 10min = 600_000ms; now is 83s before it.
        val clock = FakeJobClock(now = 517_000L, startOfDay = 0L)
        val json = """{"job_id":739,"payout_info":{"check_in_amount":5,"check_in_time":"2026-07-03T00:10:00+05:30"}}"""
        val vm = viewModel(FakeRunnerStateSource(envelope(JobWidgetName.CHECK_IN, json)), clock = clock)

        val state = vm.uiState.value
        assertIs<JobUiState.AwaitingCheckIn>(state)
        assertFalse(state.isPastCheckIn)
        assertEquals(83, state.checkInRemainingSeconds)
    }

    @Test
    fun awaitingCheckIn_countdownUsesStartTimeNotCheckinPromise() = runTest {
        // start_time 12:12 am → 12 min → 720_000ms today; now 670_000 → 50s. The checkin_promise /
        // check_in_time (05:00) are NOT used for the timer (Flutter check-in dial parity, job_accepted.dart).
        val clock = FakeJobClock(now = 670_000L, startOfDay = 0L)
        val json =
            """{"job_id":739,"start_time":"12:12 am","checkin_promise":"2026-07-03T05:00:00+05:30","payout_info":{"check_in_amount":5,"check_in_time":"2026-07-03T05:00:00+05:30"}}"""
        val vm = viewModel(FakeRunnerStateSource(envelope(JobWidgetName.CHECK_IN, json)), clock = clock)

        val state = vm.uiState.value
        assertIs<JobUiState.AwaitingCheckIn>(state)
        // 50s from start_time (12:12 am) — NOT the far checkin_promise / check_in_time (05:00).
        assertEquals(50, state.checkInRemainingSeconds)
        assertFalse(state.isPastCheckIn)
    }

    @Test
    fun awaitingCheckIn_pastDeadline_marksIsPastCheckIn() = runTest {
        // Deadline time-of-day 00:10 → 600_000ms today; now is 100s past it. The ISO date is far in the
        // future (2027) yet ignored — the deadline anchors its time-of-day to today (nominal-date immune).
        val clock = FakeJobClock(now = 700_000L, startOfDay = 0L)
        val json = """{"job_id":739,"payout_info":{"check_in_amount":5,"check_in_time":"2027-01-01T00:10:00+05:30"}}"""
        val vm = viewModel(FakeRunnerStateSource(envelope(JobWidgetName.CHECK_IN, json)), clock = clock)

        val state = vm.uiState.value
        assertIs<JobUiState.AwaitingCheckIn>(state)
        assertTrue(state.isPastCheckIn)
        assertTrue((state.checkInRemainingSeconds ?: 0) < 0)
    }

    // ── Deny / logout / next-day-attendance sub-flow ──────────────────────────
    // The deny sheet is now a stateless composable (open/closed is screen-local; it reads
    // isLastHour/lossAmount off the NewJob model — covered by JobProjectorTest). The only VM
    // behaviour is the Deny action itself: for a last-hour job the sheet's "Logout" CTA fires the
    // SAME deny_job, which is exercised here (the generic case is deny_callsDeny_noRefresh above).

    @Test
    fun deny_lastHourJob_firesSameDenyJobWithLocation() = runTest {
        val actions = FakeJobActionRepository()
        val source = FakeRunnerStateSource(
            envelope(
                JobWidgetName.NEW_JOB,
                """{"job_id":739,"is_deniable":true,"is_last_hour_job":true,"loss_amount":240}""",
            ),
        )
        val vm = viewModel(source, actions = actions, location = FakeLocationProvider(JobLocation(1.0, 2.0)))

        vm.onIntent(JobUiIntent.Deny)
        advanceUntilIdle()

        assertEquals(listOf(739), actions.denyCalls.map { it.first })
        assertEquals(JobLocation(1.0, 2.0), actions.denyCalls.single().second)
        // WS5: stage advance now arrives via MQTT — no current_state refresh.
        assertEquals(0, source.refreshCount)
    }


}
