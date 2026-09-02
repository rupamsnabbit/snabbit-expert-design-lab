package com.snabbit.runner.shared.features.job.delayedcheckin.presentation

import com.snabbit.runner.shared.core.FakeLogger
import com.snabbit.runner.shared.core.analytics.FakeAnalyticsTracker
import com.snabbit.runner.shared.core.appconfig.AppConfigStore
import com.snabbit.runner.shared.core.network.AppErrorType
import com.snabbit.runner.shared.core.network.NetworkError
import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.core.runnerstate.RunnerStateStore
import com.snabbit.runner.shared.core.session.RunnerSessionStore
import com.snabbit.runner.shared.features.job.delayedcheckin.DelayedCheckinAnalytics
import com.snabbit.runner.shared.features.job.delayedcheckin.domain.model.SupportOption
import com.snabbit.runner.shared.features.job.delayedcheckin.domain.repository.DelayedCheckinRepository
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertIs
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue
import kotlin.time.Clock
import kotlin.time.Instant

/**
 * Coverage for [DelayedCheckinViewModel]: the penalty-payload decode/clear/
 * keep-last-good rules and the signed countdown (LLD §5.3), plus the "Call
 * Support Partner" disposition funnel across Ameyo callback-mode and dial-mode
 * (FR-11/12/13). Process-lived VM pattern (backgroundScope + Unconfined test
 * dispatcher); effects are drained through a backgroundScope collector.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class DelayedCheckinViewModelTest {

    private val strings = DelayedCheckinStrings()

    /** Deterministic clock so the signed countdown never touches wall time. */
    private class FakeClock(var nowMs: Long) : Clock {
        override fun now(): Instant = Instant.fromEpochMilliseconds(nowMs)
    }

    /** Recording [DelayedCheckinRepository] double; [submitGate] pins a submit in flight. */
    private class FakeDelayedCheckinRepository(
        var submitResult: Result<String?, NetworkError> = Result.Ok(null),
        var helpline: Result<String?, NetworkError> = Result.Ok(HELPLINE),
    ) : DelayedCheckinRepository {
        data class SubmitCall(
            val runnerJobId: Int,
            val jobId: Int,
            val runnerId: Int,
            val dispositionTag: String,
            val dispositionMessage: String,
            val ameyoSupport: Boolean,
        )

        val submitCalls = mutableListOf<SubmitCall>()
        var getHelplineCalls = 0
            private set
        var submitGate: CompletableDeferred<Unit>? = null

        override suspend fun submitDisposition(
            runnerJobId: Int,
            jobId: Int,
            runnerId: Int,
            dispositionTag: String,
            dispositionMessage: String,
            ameyoSupport: Boolean,
        ): Result<String?, NetworkError> {
            submitGate?.await()
            submitCalls += SubmitCall(
                runnerJobId, jobId, runnerId, dispositionTag, dispositionMessage, ameyoSupport,
            )
            return submitResult
        }

        override suspend fun getHelpline(widgetType: String): Result<String?, NetworkError> {
            getHelplineCalls++
            return helpline
        }

        companion object {
            const val HELPLINE = "18001234567"
        }
    }

    private class Harness(
        testScope: TestScope,
        ameyo: Boolean = false,
        runnerId: Int? = 55,
        clockNowMs: Long = 1_000_000L,
    ) {
        val logger = FakeLogger()
        val store = RunnerStateStore(logger)
        val appConfig = AppConfigStore(logger)
        val session = RunnerSessionStore().apply {
            setAmeyoSupport(ameyo)
            setRunnerId(runnerId)
        }
        val repository = FakeDelayedCheckinRepository()
        val tracker = FakeAnalyticsTracker()
        val clock = FakeClock(clockNowMs)
        val effects = mutableListOf<DelayedCheckinEffect>()

        private val scope = CoroutineScope(
            testScope.backgroundScope.coroutineContext +
                UnconfinedTestDispatcher(testScope.testScheduler),
        )

        val viewModel = DelayedCheckinViewModel(
            store = store,
            appConfig = appConfig,
            session = session,
            repository = repository,
            analytics = DelayedCheckinAnalytics(tracker),
            scope = scope,
            ticker = ReachByTicker(clock),
            logger = logger,
        )

        init {
            scope.launch { viewModel.effects.collect { effects += it } }
        }

        fun push(json: String) = store.pushState(json)
        fun pushConfig(json: String) = appConfig.pushConfig(json)
    }

    // ── Fixtures ──────────────────────────────────────────────────────────

    private fun penaltyEnvelope(
        triggerAt: Long,
        receivedRedCards: Int = 0,
        totalSeconds: Int = 300,
        cardValue: Int = 50,
    ): String = """
        {"widget_name":"CHECK_IN","widget_data":{
          "delayed_checkin_penalty":{
            "countdown":{"trigger_at":$triggerAt,"total_seconds":$totalSeconds},
            "received_red_cards":$receivedRedCards,
            "card_value":$cardValue
          }
        }}
    """.trimIndent()

    /** Envelope carrying the submit ids but no penalty slice. */
    private fun idsEnvelope(runnerJobId: Int = 777, jobId: Int = 888): String =
        """{"widget_name":"CHECK_IN","widget_data":{"runner_job_id":$runnerJobId,"job_id":$jobId}}"""

    private val configWithOptions = """
        {"job_support":{"options":[
          {"id":"running_late","label":{"default_text":"Running late"}},
          {"id":"traffic","label":"Traffic jam"}
        ]}}
    """.trimIndent()

    private val option = SupportOption(id = "running_late", label = "Running late")

    // ── Case 1: penalty decodes for 0/1/2/3 red cards ─────────────────────

    @Test
    fun penaltyPayload_decodes_setsPenaltyWithReceivedRedCards_for0123() = runTest {
        val h = Harness(this)
        for (cards in 0..3) {
            // Distinct deadline per push so each is a distinct slice (avoids coalescing).
            h.push(penaltyEnvelope(triggerAt = 1_120_000L + cards * 1_000L, receivedRedCards = cards))
            val penalty = h.viewModel.uiState.value.penalty
            assertNotNull(penalty, "penalty should decode for $cards red cards")
            assertEquals(cards, penalty.receivedRedCards)
        }
    }

    // ── Case 2: absent penalty key clears to default ──────────────────────

    @Test
    fun penaltyKeyAbsent_clearsPenaltyToNull() = runTest {
        val h = Harness(this)
        h.push(penaltyEnvelope(triggerAt = 1_120_000L, receivedRedCards = 2))
        assertNotNull(h.viewModel.uiState.value.penalty)

        // FR-02: penalty resolved (key gone) → clear everything.
        h.push("""{"widget_name":"CHECK_IN","widget_data":{"job_id":1}}""")
        assertNull(h.viewModel.uiState.value.penalty)
        assertEquals(SupportSheetState.Hidden, h.viewModel.uiState.value.supportSheet)
    }

    // ── Case 3: malformed penalty keeps last good ─────────────────────────

    @Test
    fun penaltyPayloadPresentButUndecodable_keepsLastGoodPenalty() = runTest {
        val h = Harness(this)
        h.push(penaltyEnvelope(triggerAt = 1_120_000L, receivedRedCards = 2))
        val good = h.viewModel.uiState.value.penalty
        assertNotNull(good)

        // Present but junk (no trigger_at) → decode fails; last good stays (no flap).
        h.push("""{"widget_name":"CHECK_IN","widget_data":{"delayed_checkin_penalty":{"countdown":{}}}}""")
        val after = h.viewModel.uiState.value.penalty
        assertNotNull(after, "malformed payload must not clear the penalty")
        assertEquals(good.receivedRedCards, after.receivedRedCards)
    }

    // ── Case 4: signed countdown — positive then negative (isOverrun) ─────

    @Test
    fun countdown_isSigned_positiveBeforeDeadline_negativeAfter() = runTest {
        val h = Harness(this, clockNowMs = 1_000_000L)

        // Deadline 120 s in the future → positive, not overrun.
        h.push(penaltyEnvelope(triggerAt = 1_120_000L))
        assertEquals(120, h.viewModel.uiState.value.remainingSeconds)
        assertFalse(h.viewModel.uiState.value.isOverrun)

        // A re-anchored deadline 100 s in the past → negative, overrun.
        //
        // The SIGN is the contract; the magnitude deliberately is not. No consumer
        // reads how far past the deadline we are: the footer pins the timer at
        // "00:00" (`ReachBy(seconds.coerceAtLeast(0))`), the wash clamps to a full
        // bar, and `isOverrun` only tests `< 0`. The ViewModel therefore collapses
        // the whole overrun onto one sentinel value so the 1 Hz state churn stops
        // (see `countdown_overrun_pinsAtSentinel_soStateStopsChurning`); asserting an
        // exact -100 here would pin an implementation detail no UI can observe.
        h.push(penaltyEnvelope(triggerAt = 900_000L))
        assertTrue(h.viewModel.uiState.value.remainingSeconds < 0)
        assertTrue(h.viewModel.uiState.value.isOverrun)
    }

    @Test
    fun countdown_overrun_pinsAtSentinel_soStateStopsChurning() = runTest {
        val h = Harness(this, clockNowMs = 1_000_000L)

        // Already past the deadline → overrun from the first emission.
        h.push(penaltyEnvelope(triggerAt = 900_000L))
        assertEquals(-1, h.viewModel.uiState.value.remainingSeconds)
        assertTrue(h.viewModel.uiState.value.isOverrun)

        // `ReachByTicker.signedStream` never completes — past the deadline it emits
        // -101, -102, -103 … once a second forever. Each of those used to be written
        // into UiState, recomposing the whole job screen every second for a
        // pixel-identical UI, for the entire (unbounded) overrun — which is the
        // NORMAL end state of a delayed check-in. Clamped + de-duped, further
        // seconds of overrun must publish nothing new.
        repeat(5) {
            h.clock.nowMs += 1_000
            advanceTimeBy(1_500)
        }

        assertEquals(-1, h.viewModel.uiState.value.remainingSeconds)
        assertTrue(h.viewModel.uiState.value.isOverrun)
    }

    // ── Case 5: SupportClicked with empty config → toast, no sheet ────────

    @Test
    fun supportClicked_emptyConfig_emitsErrorToast_noSheet_logsConfigMissing() = runTest {
        val h = Harness(this)
        // No app config pushed → readJobSupportOptions == empty.
        h.viewModel.onIntent(DelayedCheckinIntent.SupportClicked)
        advanceUntilIdle()

        assertEquals(SupportSheetState.Hidden, h.viewModel.uiState.value.supportSheet)
        val toast = assertIs<DelayedCheckinEffect.Toast>(h.effects.single())
        assertEquals(strings.supportDetailsNotFound, toast.message)
        assertFalse(toast.success)
        assertTrue(h.tracker.trackedNames.contains("job_support_config_missing"))
        assertEquals(0, h.repository.getHelplineCalls)
    }

    // ── Case 6: SupportClicked with options → sheet Shown(options) ────────

    @Test
    fun supportClicked_withOptions_showsSheetWithOptions() = runTest {
        val h = Harness(this)
        h.pushConfig(configWithOptions)
        h.viewModel.onIntent(DelayedCheckinIntent.SupportClicked)
        advanceUntilIdle()

        val sheet = assertIs<SupportSheetState.Shown>(h.viewModel.uiState.value.supportSheet)
        assertEquals(listOf("running_late", "traffic"), sheet.options.map { it.id })
    }

    // ── Case 7: submit in AMEYO mode → callback toast, sheet closed ───────

    @Test
    fun submit_ameyoMode_serverMessage_emitsSuccessToast_closesSheet_noDial() = runTest {
        val h = Harness(this, ameyo = true)
        h.pushConfig(configWithOptions)
        h.push(idsEnvelope())
        h.repository.submitResult = Result.Ok("Callback booked!")

        h.viewModel.onIntent(DelayedCheckinIntent.SupportClicked)
        h.viewModel.onIntent(DelayedCheckinIntent.SubmitDisposition(option))
        advanceUntilIdle()

        val call = h.repository.submitCalls.single()
        assertTrue(call.ameyoSupport)
        assertEquals(777, call.runnerJobId)
        assertEquals(888, call.jobId)
        assertEquals(55, call.runnerId)
        assertEquals(SupportSheetState.Hidden, h.viewModel.uiState.value.supportSheet)
        assertFalse(h.viewModel.uiState.value.submitting)

        // Server-driven ack copy wins; no dial in callback mode.
        val toast = assertIs<DelayedCheckinEffect.Toast>(h.effects.last())
        assertEquals("Callback booked!", toast.message)
        assertTrue(toast.success)
        assertTrue(h.effects.none { it is DelayedCheckinEffect.Dial })
    }

    @Test
    fun submit_ameyoMode_noServerMessage_fallsBackToCallbackToast() = runTest {
        val h = Harness(this, ameyo = true)
        h.pushConfig(configWithOptions)
        h.push(idsEnvelope())
        h.repository.submitResult = Result.Ok(null)

        h.viewModel.onIntent(DelayedCheckinIntent.SubmitDisposition(option))
        advanceUntilIdle()

        val toast = assertIs<DelayedCheckinEffect.Toast>(h.effects.last())
        assertEquals(strings.callbackToast, toast.message)
        assertTrue(toast.success)
    }

    // ── Case 8: submit in DIAL mode → Dial effect, sheet closed ──────────

    @Test
    fun submit_dialMode_emitsDialEffect_closesSheet() = runTest {
        val h = Harness(this, ameyo = false)
        h.pushConfig(configWithOptions)
        h.push(idsEnvelope())

        // SupportClicked starts the helpline prefetch (dial mode only).
        h.viewModel.onIntent(DelayedCheckinIntent.SupportClicked)
        h.viewModel.onIntent(DelayedCheckinIntent.SubmitDisposition(option))
        advanceUntilIdle()

        val call = h.repository.submitCalls.single()
        assertFalse(call.ameyoSupport)
        assertEquals(SupportSheetState.Hidden, h.viewModel.uiState.value.supportSheet)
        val dial = assertIs<DelayedCheckinEffect.Dial>(h.effects.last())
        assertEquals(FakeDelayedCheckinRepository.HELPLINE, dial.number)
    }

    // ── Case 9: unusable ids → toast, no network call ─────────────────────

    @Test
    fun submit_unusableIds_emitsErrorToast_doesNotCallRepository() = runTest {
        val h = Harness(this, ameyo = true)
        h.pushConfig(configWithOptions)
        // runner_job_id <= 0 → refused pre-network (TR-09).
        h.push(idsEnvelope(runnerJobId = 0, jobId = 888))

        h.viewModel.onIntent(DelayedCheckinIntent.SubmitDisposition(option))
        advanceUntilIdle()

        assertTrue(h.repository.submitCalls.isEmpty())
        val toast = assertIs<DelayedCheckinEffect.Toast>(h.effects.single())
        assertEquals(strings.supportDetailsNotFound, toast.message)
        assertFalse(toast.success)
    }

    @Test
    fun submit_nullRunnerId_emitsErrorToast_doesNotCallRepository() = runTest {
        val h = Harness(this, ameyo = true, runnerId = null)
        h.pushConfig(configWithOptions)
        h.push(idsEnvelope())

        h.viewModel.onIntent(DelayedCheckinIntent.SubmitDisposition(option))
        advanceUntilIdle()

        assertTrue(h.repository.submitCalls.isEmpty())
        val toast = assertIs<DelayedCheckinEffect.Toast>(h.effects.single())
        assertEquals(strings.supportDetailsNotFound, toast.message)
        assertFalse(toast.success)
    }

    // ── Case 10: submit failure → error toast, sheet stays Shown ──────────

    @Test
    fun submit_httpError_emitsFailToast_sheetStaysShown_submittingReset() = runTest {
        val h = Harness(this, ameyo = true)
        h.pushConfig(configWithOptions)
        h.push(idsEnvelope())
        h.repository.submitResult = Result.Err(
            NetworkError.HttpError(
                statusCode = 500,
                body = "",
                errorType = AppErrorType.SERVER_DOWN,
                requestId = "req-1",
                durationMs = 0,
            ),
        )

        h.viewModel.onIntent(DelayedCheckinIntent.SupportClicked)
        h.viewModel.onIntent(DelayedCheckinIntent.SubmitDisposition(option))
        advanceUntilIdle()

        // Fail-with-retry (TR-08): sheet stays up with the selection.
        assertIs<SupportSheetState.Shown>(h.viewModel.uiState.value.supportSheet)
        assertFalse(h.viewModel.uiState.value.submitting)
        val toast = assertIs<DelayedCheckinEffect.Toast>(h.effects.last())
        assertEquals(strings.submitFailed, toast.message)
        assertFalse(toast.success)
    }

    // ── X.3 transient error_screen_load (Part 2) ─────────────────────────────

    @Test
    fun submit_httpError_firesErrorScreenLoad_notNetwork() = runTest {
        val h = Harness(this, ameyo = true)
        h.pushConfig(configWithOptions)
        h.push(idsEnvelope())
        h.repository.submitResult = Result.Err(
            NetworkError.HttpError(
                statusCode = 500, body = "", errorType = AppErrorType.SERVER_DOWN,
                requestId = "req-1", durationMs = 0,
            ),
        )

        h.viewModel.onIntent(DelayedCheckinIntent.SupportClicked)
        h.viewModel.onIntent(DelayedCheckinIntent.SubmitDisposition(option))
        advanceUntilIdle()

        val load = h.tracker.events.single { it.name == "error_screen_load" }
        assertEquals("delayed_checkin_failed", load.props["error_type"])
        assertEquals("toast", load.props["error_format"])
        assertEquals("check_in", load.props["error_context"])
        // An HTTP response arrived (server responded) → not a connectivity error.
        assertEquals(false, load.props["is_network_error"])
    }

    @Test
    fun submit_transportError_firesErrorScreenLoad_network() = runTest {
        val h = Harness(this, ameyo = true)
        h.pushConfig(configWithOptions)
        h.push(idsEnvelope())
        h.repository.submitResult = Result.Err(
            NetworkError.TransportError(AppErrorType.NO_INTERNET, requestId = "req-1", durationMs = 0),
        )

        h.viewModel.onIntent(DelayedCheckinIntent.SupportClicked)
        h.viewModel.onIntent(DelayedCheckinIntent.SubmitDisposition(option))
        advanceUntilIdle()

        val load = h.tracker.events.single { it.name == "error_screen_load" }
        assertEquals("delayed_checkin_failed", load.props["error_type"])
        assertEquals(true, load.props["is_network_error"])
    }

    // ── Case 11: DismissSheet closes; no-op mid-submit ────────────────────

    @Test
    fun dismissSheet_closesTheSheet() = runTest {
        val h = Harness(this)
        h.pushConfig(configWithOptions)
        h.viewModel.onIntent(DelayedCheckinIntent.SupportClicked)
        assertIs<SupportSheetState.Shown>(h.viewModel.uiState.value.supportSheet)

        h.viewModel.onIntent(DelayedCheckinIntent.DismissSheet)
        assertEquals(SupportSheetState.Hidden, h.viewModel.uiState.value.supportSheet)
    }

    @Test
    fun dismissSheet_whileSubmitting_isNoOp() = runTest {
        val h = Harness(this, ameyo = true)
        h.pushConfig(configWithOptions)
        h.push(idsEnvelope())
        // Pin the submit in flight so `submitting` stays true.
        val gate = CompletableDeferred<Unit>()
        h.repository.submitGate = gate

        h.viewModel.onIntent(DelayedCheckinIntent.SupportClicked)
        h.viewModel.onIntent(DelayedCheckinIntent.SubmitDisposition(option))
        assertTrue(h.viewModel.uiState.value.submitting)

        // Dismiss is ignored mid-submit — the sheet must stay open.
        h.viewModel.onIntent(DelayedCheckinIntent.DismissSheet)
        assertIs<SupportSheetState.Shown>(h.viewModel.uiState.value.supportSheet)

        // Let the submit finish so nothing leaks past the test.
        gate.complete(Unit)
        advanceUntilIdle()
        assertEquals(SupportSheetState.Hidden, h.viewModel.uiState.value.supportSheet)
    }
}
