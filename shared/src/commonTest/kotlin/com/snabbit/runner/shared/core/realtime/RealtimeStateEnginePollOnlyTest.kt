package com.snabbit.runner.shared.core.realtime

import com.snabbit.runner.shared.core.FakeLogger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * Feature #1 — the app-side MQTT kill-switch (`expert_mqtt_enabled`): poll-only
 * mode (transport never connects; HTTP reconcile loop is the data path) and the
 * live flip in/out of it via [RealtimeStateEngine.setMqttEnabled]. Fakes +
 * virtual time, matching [RealtimeStateEngineTest].
 */
@OptIn(ExperimentalCoroutinesApi::class)
class RealtimeStateEnginePollOnlyTest {

    private class Harness(scope: CoroutineScope) {
        val transport = FakeRealtimeTransport()
        val store = InMemorySnapshotStore()
        val fetcher = FakeFetcher()
        val credentials = FakeCredentials()
        val sink = RecordingSink()
        val engine = RealtimeStateEngine(
            transport = transport, store = store, fetcher = fetcher,
            credentials = credentials, sink = sink, scope = scope,
            logger = FakeLogger(), tuning = testTuning(),
        )
    }

    @Test
    fun startPollOnly_pollsCurrentState_neverConnectsTransport() = runTest {
        val h = Harness(backgroundScope)
        h.fetcher.result = envelope(seq = 7)
        h.engine.startPollOnly(testConfig()); runCurrent()

        assertEquals(RealtimeStatus.PollOnly, h.engine.status.value)
        assertTrue(h.transport.connectCalls.isEmpty(), "poll-only must never connect the socket")
        assertEquals(1, h.fetcher.calls, "polls immediately on start")
        assertEquals(7, h.store.current()?.stateSeq)

        advanceTimeBy(60_000); runCurrent()
        assertEquals(2, h.fetcher.calls, "polls again after degradedIntervalMs")
    }

    @Test
    fun setMqttEnabled_false_dropsSocketAndFallsToPolling() = runTest {
        val h = Harness(backgroundScope)
        h.engine.start(testConfig()); runCurrent()
        h.transport.setState(TransportState.Connected); runCurrent()
        assertEquals(RealtimeStatus.Connected, h.engine.status.value)

        h.fetcher.result = envelope(seq = 9)
        h.engine.setMqttEnabled(false); runCurrent()

        assertEquals(RealtimeStatus.PollOnly, h.engine.status.value)
        assertTrue(h.transport.disconnectCount >= 1, "socket dropped on disable")
        assertEquals(1, h.fetcher.calls, "poll loop started")
        assertEquals(9, h.store.current()?.stateSeq)
    }

    @Test
    fun setMqttEnabled_true_leavesPollOnlyReconnectsAndStopsPolling() = runTest {
        val h = Harness(backgroundScope)
        h.fetcher.result = envelope(seq = 1)
        h.engine.startPollOnly(testConfig()); runCurrent()

        h.engine.setMqttEnabled(true); runCurrent()
        assertEquals(RealtimeStatus.Connecting, h.engine.status.value)
        assertEquals(1, h.transport.connectCalls.size, "reconnects MQTT on re-enable")

        // MQTT connects in time → no #2 connect-timeout fallback; poll-only stays stopped.
        h.transport.setState(TransportState.Connected); runCurrent()
        h.transport.emit(message(seq = 2)); runCurrent() // suppress the retained-gap fetch
        val callsAfterConnect = h.fetcher.calls
        advanceTimeBy(180_000); runCurrent()
        assertEquals(callsAfterConnect, h.fetcher.calls, "no poll loop once MQTT reconnects")
    }

    @Test
    fun setMqttEnabled_isNoOp_whenModeUnchanged() = runTest {
        val h = Harness(backgroundScope)
        h.engine.startPollOnly(testConfig()); runCurrent()
        h.engine.setMqttEnabled(false); runCurrent() // already poll-only

        assertEquals(RealtimeStatus.PollOnly, h.engine.status.value)
        assertTrue(h.transport.connectCalls.isEmpty())
    }

    /** Regression for the review's blocker: the graceful disconnect on the live
     *  OFF-flip re-emits Reconnecting on the real transport; the engine must stay
     *  PollOnly and NOT re-arm the degraded loop (which would double-poll and,
     *  after degradedAfterMs, let a wake resurrect the killed socket). */
    @Test
    fun pollOnly_ignoresPostDisconnectReconnect_noDoublePolling() = runTest {
        val h = Harness(backgroundScope)
        h.engine.start(testConfig()); runCurrent()
        h.transport.setState(TransportState.Connected); runCurrent()

        h.fetcher.result = envelope(seq = 3)
        h.engine.setMqttEnabled(false); runCurrent()
        assertEquals(RealtimeStatus.PollOnly, h.engine.status.value)

        // Simulate the production post-disconnect re-emission.
        h.transport.setState(TransportState.Reconnecting); runCurrent()
        assertEquals(RealtimeStatus.PollOnly, h.engine.status.value)

        val pollsBefore = h.fetcher.calls
        advanceTimeBy(60_000); runCurrent()
        // Exactly ONE fetch per interval (the poll loop) — a re-armed degraded
        // loop would add a second, concurrent poll.
        assertEquals(pollsBefore + 1, h.fetcher.calls)
    }
}
