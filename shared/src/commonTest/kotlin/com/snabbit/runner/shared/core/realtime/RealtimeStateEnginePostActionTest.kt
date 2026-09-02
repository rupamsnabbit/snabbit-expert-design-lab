package com.snabbit.runner.shared.core.realtime

import com.snabbit.runner.shared.core.FakeLogger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertTrue

/**
 * Feature #4 — the post-action fallback. After a state-mutating action, if no
 * NEWER snapshot lands within postActionDeadlineMs, the engine fetches
 * current_state once (safety net) and — only when MQTT was Connected the whole
 * time — reports the miss (fail-loud telemetry). Fakes + virtual time.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class RealtimeStateEnginePostActionTest {

    private class Harness(
        scope: CoroutineScope,
        credentials: FakeCredentials = FakeCredentials(),
        /** Override to exercise the production-shaped tail; default keeps the arithmetic readable. */
        retryDelays: List<Long> = listOf(3_000, 3_000),
    ) {
        val transport = FakeRealtimeTransport()
        val store = InMemorySnapshotStore()
        val fetcher = FakeFetcher()
        val reporter = RecordingPostActionReporter()
        val outcome = RecordingOutcomeReporter()
        val engine = RealtimeStateEngine(
            transport = transport, store = store, fetcher = fetcher,
            credentials = credentials, sink = RecordingSink(), scope = scope,
            logger = FakeLogger(), tuning = EngineTuning(
                retainedWaitMs = 5_000, degradedAfterMs = 30_000, degradedIntervalMs = 60_000,
                connectTimeoutMs = 10_000, postActionDeadlineMs = 3_000,
                // Even rungs keep the virtual-time arithmetic readable: fetches at 3s, 6s, 9s.
                postActionRetryDelaysMs = retryDelays,
                jitterMs = { 0L },
            ),
            postActionReporter = reporter,
            postActionOutcomeReporter = outcome,
        )
    }

    /** Connect + seed a baseline snapshot so retained-gap is suppressed and the store has a seq. */
    private suspend fun TestScope.connectedAtSeq(h: Harness, seq: Long) {
        h.engine.start(testConfig()); runCurrent()
        h.transport.setState(TransportState.Connected); runCurrent()
        h.transport.emit(message(seq = seq)); runCurrent()
    }

    @Test
    fun connectedNoSnapshot_firesFallbackAndReports() = runTest {
        val h = Harness(backgroundScope)
        connectedAtSeq(h, 5)
        h.fetcher.result = envelope(seq = 6)

        h.engine.onPostAction("attendance"); runCurrent()
        val callsBefore = h.fetcher.calls
        advanceTimeBy(3_000); runCurrent() // post-action deadline

        assertEquals(callsBefore + 1, h.fetcher.calls, "no MQTT snapshot ⇒ one current_state fetch")
        assertEquals(listOf("attendance" to 3_000L), h.reporter.firedActions, "reports the MQTT miss")
        assertEquals(6, h.store.current()?.stateSeq, "the fallback snapshot won the seq gate")
    }

    @Test
    fun snapshotArrivesInTime_noFallbackNoReport() = runTest {
        val h = Harness(backgroundScope)
        connectedAtSeq(h, 5)
        val callsBefore = h.fetcher.calls

        h.engine.onPostAction("job_accept"); runCurrent()
        advanceTimeBy(1_000); runCurrent()
        h.transport.emit(message(seq = 6)); runCurrent() // MQTT delivers before the deadline
        advanceTimeBy(2_000); runCurrent() // deadline elapses

        assertEquals(callsBefore, h.fetcher.calls, "MQTT delivered ⇒ no fallback fetch")
        assertTrue(h.reporter.fired.isEmpty(), "delivered in time ⇒ no miss reported")
        assertEquals(6, h.store.current()?.stateSeq)
    }

    @Test
    fun pollOnly_isNoOp() = runTest {
        val h = Harness(backgroundScope)
        h.fetcher.result = envelope(seq = 1)
        h.engine.startPollOnly(testConfig()); runCurrent()
        val callsAfterStart = h.fetcher.calls // the immediate poll

        h.engine.onPostAction("attendance"); runCurrent()
        advanceTimeBy(3_000); runCurrent() // < poll interval (60s), so any fetch here is post-action's

        assertEquals(callsAfterStart, h.fetcher.calls, "poll-only: the poll loop owns refresh — no post-action arm")
        assertTrue(h.reporter.fired.isEmpty())
    }

    @Test
    fun sameAction_reArmSupersedesItsPendingLadder() = runTest {
        val h = Harness(backgroundScope)
        connectedAtSeq(h, 5)
        h.fetcher.result = envelope(seq = 6)
        val callsBefore = h.fetcher.calls

        h.engine.onPostAction("job_accept"); runCurrent()
        advanceTimeBy(1_000); runCurrent()
        h.engine.onPostAction("job_accept"); runCurrent() // repeat: cancels + replaces its own ladder
        advanceTimeBy(3_000); runCurrent() // the replacement's first rung; the original's never fires

        assertEquals(callsBefore + 1, h.fetcher.calls, "same-action re-arm ⇒ exactly one fetch")
        assertEquals(listOf("job_accept" to 3_000L), h.reporter.firedActions)
    }

    @Test
    fun differentAction_doesNotCancelAPendingLadder() = runTest {
        // The single shared deadline Job meant ANY post-action cancelled the previous action's
        // recovery mid-ladder (the old test asserted it: "only the latest action fires") — an
        // automatic AutoOT accept or an attendance action landing inside an accept's retry window
        // silently killed the accept's only recovery. Ladders are per action label now.
        val h = Harness(backgroundScope)
        connectedAtSeq(h, 5)
        h.fetcher.result = envelope(seq = 5) // stale: fetches succeed but resolve nothing

        h.engine.onPostAction("job_accept"); runCurrent()
        advanceTimeBy(1_000); runCurrent()
        h.engine.onPostAction("attendance"); runCurrent()
        advanceTimeBy(3_000); runCurrent() // t=4s: accept's rung 1 (t=3s) AND attendance's (t=4s)

        assertEquals(2, h.fetcher.calls, "both ladders fetched — the accept's survived the attendance")
        assertEquals(
            listOf("job_accept" to 3_000L, "attendance" to 3_000L),
            h.reporter.firedActions,
            "both misses reported",
        )
    }

    @Test
    fun notConnected_skipsTheMqttGraceAndFetchesAfterTheSettle() = runTest {
        // Device-observed: a runner sat in degraded HTTP poll for 36s, then an accept still burned
        // the full 2s MQTT grace before its first fetch — waiting on a transport that could not
        // deliver. Not-Connected uses the short settle instead (still non-zero: the backend
        // publishes ~0.6-1.1s after the action, so a T+0 fetch would only read pre-action state).
        val h = Harness(backgroundScope)
        h.engine.start(testConfig()); runCurrent()
        h.transport.setState(TransportState.Reconnecting); runCurrent()
        h.fetcher.result = envelope(seq = 4)

        h.engine.onPostAction("job_accept"); runCurrent()
        advanceTimeBy(500); runCurrent() // the settle, well short of the 3s deadline

        assertEquals(1, h.fetcher.calls, "not connected ⇒ fetched after the settle, not the deadline")
        assertEquals(
            listOf(Triple("job_accept", 500L, "reconnecting")),
            h.reporter.fired,
            "reports the rung that actually lapsed, not the nominal deadline",
        )
    }

    @Test
    fun connected_stillWaitsTheFullDeadlineBeforeFetching() = runTest {
        // Guards the other side: a live connection must keep its full grace, or we'd fetch out from
        // under an MQTT snapshot that was about to land and inflate the miss rate.
        val h = Harness(backgroundScope)
        connectedAtSeq(h, 5)
        h.fetcher.result = envelope(seq = 6)
        val callsBefore = h.fetcher.calls

        h.engine.onPostAction("job_accept"); runCurrent()
        advanceTimeBy(500); runCurrent()
        assertEquals(callsBefore, h.fetcher.calls, "connected ⇒ no fetch at the settle")

        advanceTimeBy(2_500); runCurrent() // out to the 3s deadline
        assertEquals(callsBefore + 1, h.fetcher.calls)
        assertEquals(listOf("job_accept" to 3_000L), h.reporter.firedActions)
    }

    @Test
    fun killSwitchFlipMidLadder_stillEmitsTheOutcomeItAlreadyReported() = runTest {
        // A fallback with no matching ladder event can't be reconciled in analysis. setMqttEnabled
        // (the RC kill-switch) flips status to PollOnly WITHOUT cancelling in-flight ladders, so a
        // ladder that had already reported its miss used to bail via `return@launch` and vanish —
        // dropping the outcome on exactly an abandoned-recovery case. (stop() is different: it
        // cancels the coroutine outright, so nothing can run — see stop_cancelsEveryPendingLadder.)
        val h = Harness(backgroundScope)
        connectedAtSeq(h, 5)
        h.fetcher.result = envelope(seq = 5) // fetch succeeds but resolves nothing

        h.engine.onPostAction("job_accept"); runCurrent()
        advanceTimeBy(3_000); runCurrent() // rung 1: reports the miss, fetches, resolves nothing
        assertEquals(1, h.reporter.fired.size, "miss reported")
        assertTrue(h.outcome.finished.isEmpty(), "ladder still running")

        h.engine.setMqttEnabled(false); runCurrent() // → PollOnly, ladder NOT cancelled
        advanceTimeBy(3_000); runCurrent() // rung 2 observes PollOnly and stands down

        assertEquals(1, h.outcome.finished.size, "abandoned ladder still reports its outcome")
        assertEquals(false, h.outcome.finished.single().resolved)
        assertEquals(1, h.reporter.fired.size, "and does not double-report the miss")
    }

    @Test
    fun unrelatedStateChange_doesNotEndTheLadder() = runTest {
        // The strand case, and the one a seq-based exit gets wrong every time: an MQTT snapshot lands
        // for something OTHER than this action (gold_coins, sheet_warnings — top-level siblings under
        // the same monotonic seq). Seq moved, the job did not. Ending here would leave the accept
        // spinner up with `resolved=true` in telemetry — the wedge, reported as healthy.
        val h = Harness(backgroundScope)
        connectedAtSeq(h, 5)
        h.fetcher.result = envelope(seq = 9, widgetTag = 5)

        h.engine.onPostAction("job_accept"); runCurrent()
        h.transport.emit(message(seq = 6, widgetTag = 5)); runCurrent() // newer seq, same widget
        advanceTimeBy(3_000); runCurrent()

        assertEquals(1, h.fetcher.calls, "an unrelated bump must not stand in for the transition")
        assertTrue(h.outcome.finished.isEmpty(), "ladder still climbing")

        h.fetcher.result = envelope(seq = 10, name = "CHECK_IN")
        advanceTimeBy(3_000); runCurrent()
        assertTrue(h.outcome.finished.single().resolved, "resolves only when the widget actually moves")
    }

    @Test
    fun ladderRunsItsFullTail_whenNothingEverMoves() = runTest {
        // Coverage gap called out in review: the harness only ever advanced ~12s, so the 20s/35s tail
        // — the reason the ladder exists — was never executed. Uses the production-shaped ladder.
        val h = Harness(backgroundScope, retryDelays = listOf(3_000, 5_000, 10_000, 15_000))
        connectedAtSeq(h, 5)
        h.fetcher.result = envelope(seq = 6, widgetTag = 5) // answers, never transitions

        h.engine.onPostAction("job_accept"); runCurrent()
        advanceTimeBy(36_000); runCurrent() // 3 + 3 + 5 + 10 + 15 = 36s, all five rungs

        assertEquals(5, h.fetcher.calls, "every rung of the tail ran")
        val done = h.outcome.finished.single()
        assertEquals(5, done.rungsRun)
        assertEquals(36_000, done.waitedMs)
        assertEquals(false, done.resolved, "never published — the signal this event exists for")
    }

    @Test
    fun stop_cancelsEveryPendingLadder() = runTest {
        val h = Harness(backgroundScope)
        connectedAtSeq(h, 5)
        h.fetcher.result = envelope(seq = 9)

        h.engine.onPostAction("job_accept"); runCurrent()
        h.engine.onPostAction("attendance"); runCurrent()
        h.engine.stop(); runCurrent()
        advanceTimeBy(12_000); runCurrent() // past every rung of both ladders

        assertEquals(0, h.fetcher.calls, "stop() cancels all pending ladders, not just the latest")
        assertTrue(h.reporter.fired.isEmpty())
        assertTrue(h.outcome.finished.isEmpty())
    }

    @Test
    fun completedLadder_doesNotBlockALaterReArmOfTheSameAction() = runTest {
        // Guards the invokeOnCompletion deregistration: a finished ladder must remove its own map
        // entry so a later action with the same label arms a fresh ladder cleanly.
        val h = Harness(backgroundScope)
        connectedAtSeq(h, 5)
        h.fetcher.result = envelope(seq = 6)

        h.engine.onPostAction("job_accept"); runCurrent()
        advanceTimeBy(3_000); runCurrent() // rung 1 fetch carries seq 6 — ladder resolves and ends
        assertEquals(1, h.fetcher.calls)
        assertEquals(1, h.outcome.finished.size)

        h.fetcher.result = envelope(seq = 7)
        h.engine.onPostAction("job_accept"); runCurrent()
        advanceTimeBy(3_000); runCurrent()

        assertEquals(2, h.fetcher.calls, "a fresh ladder armed and fetched for the re-offered action")
        assertTrue(h.outcome.finished.all { it.resolved })
    }

    @Test
    fun notConnected_fetchesAndReportsWithStatus() = runTest {
        // A miss while reconnecting is still a miss. It used to go unreported, which made the
        // measured miss-rate a floor: any change that merely moved runners out of Connected would
        // have looked like an improvement. The status dimension keeps the branches separable.
        val h = Harness(backgroundScope)
        h.engine.start(testConfig()); runCurrent()
        h.transport.setState(TransportState.Reconnecting); runCurrent() // degraded countdown (30s) armed, not the loop yet
        h.fetcher.result = envelope(seq = 1)
        val callsBefore = h.fetcher.calls

        h.engine.onPostAction("checkout"); runCurrent()
        advanceTimeBy(3_000); runCurrent()

        assertEquals(callsBefore + 1, h.fetcher.calls, "still fetches the safety net while reconnecting")
        assertEquals(
            // 500, not the 3s deadline: Reconnecting has no MQTT to wait for, so the first rung is
            // the settle (see notConnected_skipsTheMqttGraceAndFetchesAfterTheSettle).
            listOf(Triple("checkout", 500L, "reconnecting")),
            h.reporter.fired,
            "reported, and tagged with the status that decided the recovery path",
        )
    }

    @Test
    fun stopped_skipsFetch_butStillReportsTheMiss() = runTest {
        // Auth refused + no fresh JWT ⇒ Stopped(NotAuthorized). The fallback must NOT
        // fetch current_state (honors the "no HTTP while auth-dead" invariant, matching
        // armConnectDeadline).
        val h = Harness(backgroundScope, credentials = FakeCredentials(next = null))
        h.engine.start(testConfig()); runCurrent()
        h.transport.setState(TransportState.Connected); runCurrent()
        h.transport.setState(TransportState.Disconnected(DisconnectReason.NotAuthorized)); runCurrent()
        assertIs<RealtimeStatus.Stopped>(h.engine.status.value)
        h.fetcher.result = envelope(seq = 9)

        h.engine.onPostAction("attendance"); runCurrent()
        advanceTimeBy(3_000); runCurrent()

        assertEquals(0, h.fetcher.calls, "auth-dead ⇒ no current_state fetch")
        assertEquals(
            // 500: Stopped has no MQTT to wait for either, so the miss is declared at the settle.
            listOf(Triple("attendance", 500L, "stopped")),
            h.reporter.fired,
            "skipping the fetch is a recovery decision, not a reason to hide the miss",
        )
    }

    @Test
    fun firstFetchTooEarly_ladderRetriesUntilTheTransitionLands() = runTest {
        // THE regression this ladder exists for. In production the first rung fires 2s after the
        // action's 2xx (RC pinned to its floor), by which point the backend has often ACKed the
        // accept without transitioning the job yet — current_state returns the PRE-action seq and
        // loses the seq gate. The single-shot fallback stopped right here, leaving the runner on a
        // spinner no later event could clear.
        val h = Harness(backgroundScope)
        connectedAtSeq(h, 5) // baseline widget = SPIKE/{seq:5}
        // Production shape: `state_seq` is minted when the backend COMPUTES a response, so an
        // untransitioned fetch still returns a strictly newer seq — it just carries the same widget.
        // A seq-based exit test would pass here while the runner stayed stuck.
        h.fetcher.result = envelope(seq = 6, widgetTag = 5)

        h.engine.onPostAction("job_accept"); runCurrent()
        advanceTimeBy(3_000); runCurrent()

        assertEquals(1, h.fetcher.calls)
        assertEquals(6, h.store.current()?.stateSeq, "the newer seq IS stored — applyIfNewer is right")
        assertTrue(h.outcome.finished.isEmpty(), "but the job hasn't moved, so the ladder is still climbing")

        h.fetcher.result = envelope(seq = 7, name = "CHECK_IN") // backend has now transitioned
        advanceTimeBy(3_000); runCurrent()

        assertEquals(2, h.fetcher.calls, "the ladder fetched again instead of giving up")
        assertEquals(7, h.store.current()?.stateSeq, "the retry carried the transition")
        assertEquals(1, h.reporter.fired.size, "the miss is still reported exactly ONCE, as before")
        assertEquals(
            listOf(RecordingOutcomeReporter.Finished("job_accept", 2, 6_000, true, "connected")),
            h.outcome.finished,
            "ends on the rung that resolved it — not a rung later",
        )
    }

    @Test
    fun neverPublished_exhaustsTheLadderAndReportsUnresolved() = runTest {
        // The other side of the same event: state asked for repeatedly over the whole ladder and
        // never moved. `resolved=false` is what separates "the backend was slow" from "the backend
        // never published" — the single-shot fallback reported both identically.
        val h = Harness(backgroundScope)
        connectedAtSeq(h, 5)
        // Each rung gets a fresh seq (as production does) but the SAME widget — the backend is
        // answering, it just never transitions the job. This is the population `resolved=false` is
        // meant to name, and a seq-based exit could never reach it.
        h.fetcher.result = envelope(seq = 6, widgetTag = 5)

        h.engine.onPostAction("job_accept"); runCurrent()
        advanceTimeBy(9_000); runCurrent() // all three rungs

        assertEquals(3, h.fetcher.calls, "one fetch per rung")
        assertEquals(1, h.reporter.fired.size, "still one fallback event, not one per attempt")
        assertEquals(
            listOf(RecordingOutcomeReporter.Finished("job_accept", 3, 9_000, false, "connected")),
            h.outcome.finished,
        )
    }

    @Test
    fun failedFetch_doesNotConsumeTheOnlyAttempt() = runTest {
        // reconcileNow() gives up silently when the fetch returns null — which, with a single shot,
        // meant one timeout removed the action's entire recovery. (The reconcileInFlight dedupe
        // drop has the same shape and is covered by the same retry.)
        val h = Harness(backgroundScope)
        connectedAtSeq(h, 5)
        h.fetcher.result = null // fetch fails

        h.engine.onPostAction("check_in"); runCurrent()
        advanceTimeBy(3_000); runCurrent()
        assertEquals(5, h.store.current()?.stateSeq, "failed fetch changed nothing")

        h.fetcher.result = envelope(seq = 7)
        advanceTimeBy(3_000); runCurrent()

        assertEquals(7, h.store.current()?.stateSeq, "the next rung recovered the failed fetch")
        assertTrue(h.outcome.finished.single().resolved)
    }

    @Test
    fun authDeadAtFirstRung_recoversOnceTheStatusClears() = runTest {
        // Stopped/Offline rungs skip the fetch but STAY on the ladder. Previously those states had
        // no recovery at all for the pending action: the single attempt was spent on a rung that
        // deliberately didn't fetch, and nothing retried once the status cleared.
        val h = Harness(backgroundScope, credentials = FakeCredentials(next = null))
        connectedAtSeq(h, 5)
        h.transport.setState(TransportState.Disconnected(DisconnectReason.NotAuthorized)); runCurrent()
        assertIs<RealtimeStatus.Stopped>(h.engine.status.value)
        h.fetcher.result = envelope(seq = 6)

        h.engine.onPostAction("job_accept"); runCurrent()
        advanceTimeBy(3_000); runCurrent()
        assertEquals(0, h.fetcher.calls, "auth-dead rung skips the fetch (no HTTP while auth-dead)")

        h.transport.setState(TransportState.Connected); runCurrent() // re-auth succeeded
        advanceTimeBy(3_000); runCurrent()

        assertEquals(1, h.fetcher.calls, "the ladder outlasted the outage and fetched once back up")
        assertEquals(6, h.store.current()?.stateSeq)
        assertTrue(h.outcome.finished.single().resolved, "recovered rather than being stranded")
    }

    @Test
    fun stop_cancelsPostActionDeadline() = runTest {
        val h = Harness(backgroundScope)
        h.engine.start(testConfig()); runCurrent()
        h.transport.setState(TransportState.Connected); runCurrent()
        h.fetcher.result = envelope(seq = 9)

        h.engine.onPostAction("attendance"); runCurrent()
        h.engine.stop(); runCurrent()
        advanceTimeBy(3_000); runCurrent()

        assertEquals(0, h.fetcher.calls, "stop() cancels the pending post-action fallback")
        assertTrue(h.reporter.fired.isEmpty())
    }
}
