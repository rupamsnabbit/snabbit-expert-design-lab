package com.snabbit.runner.shared.core.realtime

import com.snabbit.runner.shared.core.FakeLogger
import com.snabbit.runner.shared.core.connectivity.ConnectivityStatus
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals

/**
 * Feature #2 — connect-timeout fallback + connectivity gate. If MQTT doesn't reach
 * Connected within connectTimeoutMs of start, fall to the HTTP poll loop; when the
 * device is offline, surface [RealtimeStatus.Offline] and skip the futile fetch.
 * MQTT keeps auto-reconnecting, so a Connected cancels the loop and switches back.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class RealtimeStateEngineConnectTimeoutTest {

    private fun tuning() = EngineTuning(
        retainedWaitMs = 5_000, degradedAfterMs = 30_000, degradedIntervalMs = 60_000,
        connectTimeoutMs = 10_000, jitterMs = { 0L },
    )

    private class Harness(scope: CoroutineScope, network: FakeNetworkMonitor, tuning: EngineTuning) {
        val transport = FakeRealtimeTransport()
        val store = InMemorySnapshotStore()
        val fetcher = FakeFetcher()
        val engine = RealtimeStateEngine(
            transport = transport, store = store, fetcher = fetcher,
            credentials = FakeCredentials(), sink = RecordingSink(), scope = scope,
            logger = FakeLogger(), tuning = tuning, network = network,
        )
    }

    @Test
    fun connectTimeout_online_fallsToPolling() = runTest {
        val h = Harness(backgroundScope, FakeNetworkMonitor(ConnectivityStatus.Online), tuning())
        h.fetcher.result = envelope(seq = 1)
        h.engine.start(testConfig()); runCurrent()
        assertEquals(RealtimeStatus.Connecting, h.engine.status.value)

        advanceTimeBy(10_000); runCurrent() // connect timeout
        assertEquals(RealtimeStatus.Degraded, h.engine.status.value)
        assertEquals(1, h.fetcher.calls, "polls current_state on timeout")

        advanceTimeBy(60_000); runCurrent()
        assertEquals(2, h.fetcher.calls, "keeps polling on the interval")
    }

    @Test
    fun connectTimeout_offline_surfacesOfflineNoFetch() = runTest {
        val h = Harness(backgroundScope, FakeNetworkMonitor(ConnectivityStatus.Offline), tuning())
        h.fetcher.result = envelope(seq = 1)
        h.engine.start(testConfig()); runCurrent()

        advanceTimeBy(10_000); runCurrent()
        assertEquals(RealtimeStatus.Offline, h.engine.status.value)
        assertEquals(0, h.fetcher.calls, "offline ⇒ no futile REST call")
    }

    @Test
    fun connectTimeout_badConnection_pollsDegraded() = runTest {
        // BadConnection is a slow-but-usable link — REST still works, so poll (Degraded)
        // rather than surface Offline. Only a true Offline skips the futile fetch.
        val h = Harness(backgroundScope, FakeNetworkMonitor(ConnectivityStatus.BadConnection), tuning())
        h.fetcher.result = envelope(seq = 1)
        h.engine.start(testConfig()); runCurrent()

        advanceTimeBy(10_000); runCurrent() // connect timeout
        assertEquals(RealtimeStatus.Degraded, h.engine.status.value)
        assertEquals(1, h.fetcher.calls, "bad connection still polls current_state")
    }

    @Test
    fun onlineToOffline_nextTickSurfacesOfflineNoFetch() = runTest {
        val net = FakeNetworkMonitor(ConnectivityStatus.Online)
        val h = Harness(backgroundScope, net, tuning())
        h.fetcher.result = envelope(seq = 1)
        h.engine.start(testConfig()); runCurrent()
        advanceTimeBy(10_000); runCurrent() // connect timeout → polling
        assertEquals(RealtimeStatus.Degraded, h.engine.status.value)
        assertEquals(1, h.fetcher.calls)

        // Device drops offline mid-fallback — the next poll tick reads Offline and skips REST.
        net.set(ConnectivityStatus.Offline); runCurrent()
        advanceTimeBy(60_000); runCurrent()
        assertEquals(RealtimeStatus.Offline, h.engine.status.value)
        assertEquals(1, h.fetcher.calls, "offline ⇒ the tick skips the fetch")
    }

    @Test
    fun connectsWithinTimeout_noFallback() = runTest {
        val h = Harness(backgroundScope, FakeNetworkMonitor(ConnectivityStatus.Online), tuning())
        h.engine.start(testConfig()); runCurrent()
        h.transport.setState(TransportState.Connected); runCurrent()
        h.transport.emit(message(seq = 5)); runCurrent() // suppress the retained-gap fetch
        assertEquals(RealtimeStatus.Connected, h.engine.status.value)

        advanceTimeBy(70_000); runCurrent() // past connect timeout + an interval
        assertEquals(RealtimeStatus.Connected, h.engine.status.value)
        assertEquals(0, h.fetcher.calls, "connected in time ⇒ no fallback poll")
    }

    @Test
    fun offlineToOnline_resumesPolling() = runTest {
        val net = FakeNetworkMonitor(ConnectivityStatus.Offline)
        val h = Harness(backgroundScope, net, tuning())
        h.fetcher.result = envelope(seq = 1)
        h.engine.start(testConfig()); runCurrent()
        advanceTimeBy(10_000); runCurrent()
        assertEquals(RealtimeStatus.Offline, h.engine.status.value)

        net.set(ConnectivityStatus.Online); runCurrent()
        assertEquals(RealtimeStatus.Degraded, h.engine.status.value)
        assertEquals(1, h.fetcher.calls, "regaining internet reconciles immediately")
    }

    @Test
    fun mqttConnects_cancelsFallbackAndSwitchesBack() = runTest {
        val h = Harness(backgroundScope, FakeNetworkMonitor(ConnectivityStatus.Online), tuning())
        h.fetcher.result = envelope(seq = 1)
        h.engine.start(testConfig()); runCurrent()
        advanceTimeBy(10_000); runCurrent()
        assertEquals(RealtimeStatus.Degraded, h.engine.status.value)
        val pollsBeforeConnect = h.fetcher.calls

        h.transport.setState(TransportState.Connected); runCurrent()
        h.transport.emit(message(seq = 9)); runCurrent() // suppress retained-gap fetch
        assertEquals(RealtimeStatus.Connected, h.engine.status.value)

        advanceTimeBy(180_000); runCurrent()
        assertEquals(pollsBeforeConnect, h.fetcher.calls, "fallback poll stops after reconnect")
    }
}
