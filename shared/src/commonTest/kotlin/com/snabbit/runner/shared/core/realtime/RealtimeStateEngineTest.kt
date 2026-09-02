package com.snabbit.runner.shared.core.realtime

import com.snabbit.runner.shared.core.FakeLogger
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertTrue

/**
 * LLD App A rows: state machine, reason-code policy, reconcile matrix,
 * first-snapshot flow — all on fakes + virtual time.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class RealtimeStateEngineTest {

    private class Harness(scope: kotlinx.coroutines.CoroutineScope) {
        val transport = FakeRealtimeTransport()
        val store = InMemorySnapshotStore()
        val fetcher = FakeFetcher()
        val credentials = FakeCredentials()
        val sink = RecordingSink()
        val discards = RecordingDiscardReporter()
        val engine = RealtimeStateEngine(
            transport = transport, store = store, fetcher = fetcher,
            credentials = credentials, sink = sink, scope = scope,
            logger = FakeLogger(), tuning = testTuning(),
            discardReporter = discards,
        )
    }

    @Test
    fun staleSnapshot_isDiscarded_andReportedWithBothSeqs() = runTest {
        // The discard used to leave no trace at all in production (logger.d is release-gated to a
        // no-op), which is why "the state arrived and we dropped it" was indistinguishable from "it
        // never arrived". Both seqs are reported because an older snapshot and a re-published
        // identical one are different failures.
        val h = Harness(backgroundScope)
        h.engine.start(testConfig()); runCurrent()
        h.transport.setState(TransportState.Connected); runCurrent()
        h.transport.emit(message(seq = 7)); runCurrent()

        h.transport.emit(message(seq = 5)); runCurrent()   // older
        h.transport.emit(message(seq = 7)); runCurrent()   // identical — a re-publish

        assertEquals(
            listOf(
                Triple(5L, 7L, SnapshotSource.MQTT),
                Triple(7L, 7L, SnapshotSource.MQTT),
            ),
            h.discards.discarded,
        )
        assertEquals(7, h.store.current()?.stateSeq, "the incumbent snapshot is untouched")
    }

    @Test
    fun newerSnapshot_isApplied_andReportsNoDiscard() = runTest {
        val h = Harness(backgroundScope)
        h.engine.start(testConfig()); runCurrent()
        h.transport.setState(TransportState.Connected); runCurrent()
        h.transport.emit(message(seq = 7)); runCurrent()

        h.transport.emit(message(seq = 8)); runCurrent()

        assertTrue(h.discards.discarded.isEmpty(), "the healthy path must stay silent")
        assertEquals(8, h.store.current()?.stateSeq)
    }

    @Test
    fun retained_snapshot_applies_and_suppresses_connect_gap_fetch() = runTest {
        val h = Harness(backgroundScope)
        h.engine.start(testConfig()); runCurrent()
        h.transport.setState(TransportState.Connected); runCurrent()
        h.transport.emit(message(seq = 5)); runCurrent()

        assertEquals(1, h.sink.applied.size)
        assertEquals(SnapshotSource.MQTT, h.sink.applied[0].second)
        advanceTimeBy(6_000); runCurrent()               // past retainedWaitMs
        assertEquals(0, h.fetcher.calls, "retained arrived — no §6.9 backstop fetch expected")
    }

    @Test
    fun empty_topic_triggers_connect_gap_reconcile() = runTest {
        val h = Harness(backgroundScope)
        h.fetcher.result = envelope(seq = 7)
        h.engine.start(testConfig()); runCurrent()
        h.transport.setState(TransportState.Connected); runCurrent()

        advanceTimeBy(5_001); runCurrent()
        assertEquals(1, h.fetcher.calls, "no retained within window ⇒ exactly one backstop fetch")
        assertEquals(SnapshotSource.FETCH, h.sink.applied.single().second)
        assertEquals(7, h.store.current()?.stateSeq)
    }

    @Test
    fun stale_and_duplicate_snapshots_are_discarded() = runTest {
        val h = Harness(backgroundScope)
        h.engine.start(testConfig()); runCurrent()
        h.transport.setState(TransportState.Connected); runCurrent()
        h.transport.emit(message(seq = 5)); runCurrent()
        h.transport.emit(message(seq = 5)); runCurrent()  // QoS1 duplicate
        h.transport.emit(message(seq = 3)); runCurrent()  // out-of-order
        assertEquals(1, h.sink.applied.size)
        assertEquals(5, h.store.current()?.stateSeq)
    }

    @Test
    fun lower_seq_is_rejected_regardless_of_epoch() = runTest {
        val h = Harness(backgroundScope)
        h.engine.start(testConfig()); runCurrent()
        h.transport.setState(TransportState.Connected); runCurrent()
        h.transport.emit(message(seq = 1043, epoch = 7)); runCurrent()
        h.transport.emit(message(seq = 2, epoch = 8)); runCurrent()  // higher epoch, lower seq
        assertEquals(1, h.sink.applied.size, "ordering is by state_seq only — epoch is ignored")
        assertEquals(1043, h.store.current()?.stateSeq)
    }

    @Test
    fun not_authorized_refreshes_jwt_and_reconnects_once() = runTest {
        // Only a server-sent DISCONNECT(NOT_AUTHORIZED) reaches this path — a CONNACK-refused
        // reconnect is Network (see HiveMqttTransport.mapDisconnect), handled by auto-reconnect.
        val h = Harness(backgroundScope)
        h.engine.start(testConfig()); runCurrent()
        h.transport.setState(TransportState.Disconnected(DisconnectReason.NotAuthorized)); runCurrent()

        assertEquals(1, h.credentials.calls)
        assertEquals(2, h.transport.connectCalls.size)
        assertEquals("fresh-jwt", h.transport.connectCalls.last().password)

        // refused again without an intervening Connected ⇒ stop, don't loop (§6.1)
        h.transport.setState(TransportState.Disconnected(DisconnectReason.NotAuthorized)); runCurrent()
        assertIs<RealtimeStatus.Stopped>(h.engine.status.value)
        assertEquals(2, h.transport.connectCalls.size)
    }

    @Test
    fun session_taken_over_stops_reconnecting() = runTest {
        val h = Harness(backgroundScope)
        h.engine.start(testConfig()); runCurrent()
        h.transport.setState(TransportState.Disconnected(DisconnectReason.SessionTakenOver)); runCurrent()
        val status = h.engine.status.value
        assertIs<RealtimeStatus.Stopped>(status)
        assertIs<DisconnectReason.SessionTakenOver>(status.reason)
        assertEquals(1, h.transport.connectCalls.size, "must not reconnect-fight (§6.1)")
    }

    @Test
    fun degraded_runs_periodic_reconcile_until_connected() = runTest {
        val h = Harness(backgroundScope)
        h.fetcher.result = envelope(seq = 1)
        h.engine.start(testConfig()); runCurrent()
        h.transport.setState(TransportState.Reconnecting); runCurrent()

        advanceTimeBy(30_001); runCurrent()               // degradedAfterMs
        assertEquals(RealtimeStatus.Degraded, h.engine.status.value)
        advanceTimeBy(120_000); runCurrent()
        assertTrue(h.fetcher.calls >= 2, "DEGRADED loop is the data path (§6.4); calls=${h.fetcher.calls}")

        h.transport.setState(TransportState.Connected); runCurrent()
        h.transport.emit(message(seq = 50)); runCurrent() // suppress connect-gap backstop
        val settled = h.fetcher.calls
        advanceTimeBy(300_000); runCurrent()
        assertEquals(settled, h.fetcher.calls, "loop must stop once Connected")
    }

    @Test
    fun concurrent_reconcile_triggers_coalesce_into_one_follow_up_fetch() = runTest {
        // Was: the second trigger was DROPPED outright ("in-flight dedupe"). That silently no-op'd
        // triggers with no retry of their own — a foreground wake landing during a poll/ladder
        // fetch never refreshed anything. Now the in-flight fetch runs ONE follow-up before
        // releasing the gate: N concurrent triggers still collapse, but into one extra fetch
        // whose result is at-least-as-fresh-as the last trigger, not into nothing.
        val h = Harness(backgroundScope)
        h.fetcher.result = envelope(seq = 1)
        h.fetcher.gate = CompletableDeferred()
        h.engine.start(testConfig()); runCurrent()

        h.engine.onWakeSignal(WakeReason.FCM_DATA)
        h.engine.onWakeSignal(WakeReason.APP_FOREGROUND) // lands while the first fetch is gated
        runCurrent()
        h.fetcher.gate!!.complete(Unit); runCurrent()
        assertEquals(2, h.fetcher.calls, "second trigger coalesces into one follow-up, not zero")

        // And the follow-up marker doesn't linger: a later lone trigger fetches exactly once.
        h.engine.onWakeSignal(WakeReason.FCM_DATA); runCurrent()
        assertEquals(3, h.fetcher.calls, "no stale follow-up double-fetch on the next trigger")
    }

    @Test
    fun newer_schema_version_is_discarded_and_reconciled() = runTest {
        val h = Harness(backgroundScope)
        h.fetcher.result = envelope(seq = 9)
        h.engine.start(testConfig()); runCurrent()
        h.transport.setState(TransportState.Connected); runCurrent()
        h.transport.emit(message(seq = 99, schema = 2)); runCurrent()

        assertEquals(1, h.fetcher.calls, "schema guard ⇒ trust HTTP (App B)")
        assertEquals(9, h.store.current()?.stateSeq)
        assertEquals(SnapshotSource.FETCH, h.sink.applied.single().second)
    }

    @Test
    fun wake_afterStop_doesNothing() = runTest {
        // onWakeSignal now queues its WHOLE body on the confined scope, so stop() can land between
        // the enqueue and the run. stop() never clears `config`, so without the started-guard the
        // queued wake would build a FRESH auto-reconnecting client on a torn-down engine — one the
        // already-returned stop() will never disconnect — plus fire HTTP on a dead engine.
        val h = Harness(backgroundScope)
        h.fetcher.result = envelope(seq = 1)
        h.engine.start(testConfig()); runCurrent()
        val connectsAfterStart = h.transport.connectCalls.size
        val fetchesAfterStart = h.fetcher.calls

        h.engine.stop()
        h.engine.onWakeSignal(WakeReason.APP_FOREGROUND)
        runCurrent()

        assertEquals(connectsAfterStart, h.transport.connectCalls.size, "no socket on a stopped engine")
        assertEquals(fetchesAfterStart, h.fetcher.calls, "no HTTP on a stopped engine")
    }

    @Test
    fun wake_whileAuthDead_reconnectsButDoesNotFetch() = runTest {
        // Stopped means the token was REFUSED. The engine already refuses to poll in that state
        // ("sign-out owns recovery"), but a KMP-cohort pull-to-refresh reached reconcileNow through
        // the bridge and fetched anyway — unthrottled and tap-repeatable — breaking that invariant
        // from the outside. The reconnect stays: jwtProvider re-reads storage, so a token written
        // since may revive the socket.
        val h = Harness(backgroundScope)
        h.credentials.next = null // no fresh JWT ⇒ the auth-refresh path lands in Stopped
        h.fetcher.result = envelope(seq = 1)
        h.engine.start(testConfig()); runCurrent()
        h.transport.setState(TransportState.Connected); runCurrent()
        h.transport.setState(TransportState.Disconnected(DisconnectReason.NotAuthorized)); runCurrent()
        assertIs<RealtimeStatus.Stopped>(h.engine.status.value)
        val fetchesBefore = h.fetcher.calls
        val connectsBefore = h.transport.connectCalls.size

        h.engine.onWakeSignal(WakeReason.USER_REFRESH); runCurrent()

        assertEquals(fetchesBefore, h.fetcher.calls, "no HTTP against a refused token")
        assertEquals(connectsBefore + 1, h.transport.connectCalls.size, "but the socket re-attempt stays")
    }

    @Test
    fun wake_whileOffline_stillFetches() = runTest {
        // The other side: Offline is not auth-dead. Connectivity can return before the monitor
        // notices, so a user-initiated refresh is a fair prompt to try — one request, no auth noise.
        val h = Harness(backgroundScope)
        h.fetcher.result = envelope(seq = 1)
        h.engine.start(testConfig()); runCurrent()
        val before = h.fetcher.calls

        h.engine.onWakeSignal(WakeReason.USER_REFRESH); runCurrent()

        assertEquals(before + 1, h.fetcher.calls)
    }

    @Test
    fun wake_reconnects_when_transport_is_down() = runTest {
        val h = Harness(backgroundScope)
        h.engine.start(testConfig()); runCurrent()
        h.transport.setState(TransportState.Disconnected(DisconnectReason.SessionTakenOver)); runCurrent()
        h.engine.onWakeSignal(WakeReason.FCM_DATA); runCurrent()
        assertEquals(2, h.transport.connectCalls.size, "explicit wake may re-attempt after a stop")
    }
}
