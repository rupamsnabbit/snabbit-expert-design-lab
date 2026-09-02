package com.snabbit.runner.shared.core.network

import com.snabbit.runner.shared.core.CurrentTimeMs
import com.snabbit.runner.shared.core.network.interceptors.UnauthorizedResponseObserver
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals

/**
 * The 401-burst debounce honours its RC window.
 *
 * Why this knob exists: the window decides how many logouts a token-service wobble
 * produces. Too narrow and a 401 storm mass-logs-out runners; the value must be
 * widenable without a release, which means it has to be read per response rather
 * than captured when the observer is constructed.
 */
class UnauthorizedDebounceTuningTest {

    // Starts well past any window under test. `lastFired` initialises to 0, so a
    // clock starting at 0 would put the FIRST 401 inside the debounce and suppress
    // it — production never sees that because it wires a wall clock. The existing
    // SnabbitHttpClientTest 401 case steps its clock for the same reason.
    private class Clock(var now: Long = START) : CurrentTimeMs {
        override fun invoke(): Long = now
    }

    private suspend fun observerWith(debounceMs: Long): Triple<UnauthorizedResponseObserver, Clock, () -> Int> {
        var fires = 0
        val dispatcher = UnauthorizedDispatcher().also { it.setEmitter { fires++ } }
        val clock = Clock()
        val observer = UnauthorizedResponseObserver(
            dispatcher = dispatcher,
            currentTimeMs = clock,
            networkTuningStore = fixedNetworkTuningStore(
                NetworkTuning(unauthorizedDebounceMs = debounceMs),
            ),
        )
        return Triple(observer, clock) { fires }
    }

    @Test
    fun burstWithinTheWindow_firesOnce() = runTest {
        val (observer, clock, fires) = observerWith(10_000)

        repeat(3) { observer.notifyResponse(401) }
        clock.now = START + 9_999
        observer.notifyResponse(401)

        assertEquals(1, fires())
    }

    @Test
    fun pastTheWindow_firesAgain() = runTest {
        val (observer, clock, fires) = observerWith(10_000)

        observer.notifyResponse(401)
        clock.now = START + 10_000
        observer.notifyResponse(401)

        assertEquals(2, fires())
    }

    // A wider RC window must actually suppress a 401 that the shipped 2 s default
    // would have let through — otherwise the knob does nothing for the incident.
    @Test
    fun wideningTheWindow_suppressesWhatTheDefaultWouldFire() = runTest {
        val (wide, wideClock, wideFires) = observerWith(30_000)
        val (shipped, shippedClock, shippedFires) =
            observerWith(NetworkTuning.DEFAULT_UNAUTHORIZED_DEBOUNCE_MS)

        wide.notifyResponse(401); shipped.notifyResponse(401)
        wideClock.now = START + 5_000; shippedClock.now = START + 5_000
        wide.notifyResponse(401); shipped.notifyResponse(401)

        assertEquals(1, wideFires())
        assertEquals(2, shippedFires())
    }

    private companion object {
        const val START = 1_000_000L
    }
}
