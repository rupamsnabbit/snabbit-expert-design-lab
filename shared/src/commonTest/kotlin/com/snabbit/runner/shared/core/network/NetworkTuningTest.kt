package com.snabbit.runner.shared.core.network

import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * The app-wide, RC-driven HTTP timeout budget.
 *
 * The clamp band is the safety-critical part: the connect budget also bounds
 * [SnabbitHttpClientImpl]'s two cold-start gates, so a bad push doesn't merely
 * slow requests down — it can start failing calls that would have succeeded.
 * Every branch of the resolve (absent · valid · non-positive · under floor ·
 * over ceiling) is covered here.
 */
class NetworkTuningTest {

    private fun rc(vararg pairs: Pair<String, Int>) = FakeIntRemoteConfigGateway(pairs.toMap())

    @Test
    fun absentKeys_resolveToShippedDefaults() = runTest {
        val tuning = networkTuning(rc())

        assertEquals(NetworkTuning.DEFAULT_CONNECT_TIMEOUT_MS, tuning.connectTimeoutMs)
        assertEquals(NetworkTuning.DEFAULT_RECEIVE_TIMEOUT_MS, tuning.receiveTimeoutMs)
    }

    @Test
    fun remoteValues_areConvertedFromSecondsToMillis() = runTest {
        val tuning = networkTuning(
            rc(
                NetworkTuning.KEY_CONNECT_TIMEOUT_SECS to 15,
                NetworkTuning.KEY_RECEIVE_TIMEOUT_SECS to 45,
            ),
        )

        assertEquals(15_000L, tuning.connectTimeoutMs)
        assertEquals(45_000L, tuning.receiveTimeoutMs)
    }

    @Test
    fun eachKey_isIndependent() = runTest {
        val tuning = networkTuning(rc(NetworkTuning.KEY_RECEIVE_TIMEOUT_SECS to 90))

        assertEquals(NetworkTuning.DEFAULT_CONNECT_TIMEOUT_MS, tuning.connectTimeoutMs)
        assertEquals(90_000L, tuning.receiveTimeoutMs)
    }

    // Zero is the "unset/disabled" sentinel an operator reaches for to revert a
    // key; it must restore the SHIPPED default, not the clamp floor — matching
    // runner_http.dart's `> 0 ? value : default` for the Dart-side equivalent.
    @Test
    fun zero_fallsBackToShippedDefault_notTheFloor() = runTest {
        val tuning = networkTuning(
            rc(
                NetworkTuning.KEY_CONNECT_TIMEOUT_SECS to 0,
                NetworkTuning.KEY_RECEIVE_TIMEOUT_SECS to 0,
            ),
        )

        assertEquals(NetworkTuning.DEFAULT_CONNECT_TIMEOUT_MS, tuning.connectTimeoutMs)
        assertEquals(NetworkTuning.DEFAULT_RECEIVE_TIMEOUT_MS, tuning.receiveTimeoutMs)
    }

    @Test
    fun negative_fallsBackToShippedDefault() = runTest {
        val tuning = networkTuning(
            rc(
                NetworkTuning.KEY_CONNECT_TIMEOUT_SECS to -30,
                NetworkTuning.KEY_RECEIVE_TIMEOUT_SECS to -1,
            ),
        )

        assertEquals(NetworkTuning.DEFAULT_CONNECT_TIMEOUT_MS, tuning.connectTimeoutMs)
        assertEquals(NetworkTuning.DEFAULT_RECEIVE_TIMEOUT_MS, tuning.receiveTimeoutMs)
    }

    @Test
    fun belowFloor_clampsUp() = runTest {
        val tuning = networkTuning(
            rc(
                NetworkTuning.KEY_CONNECT_TIMEOUT_SECS to 1,
                NetworkTuning.KEY_RECEIVE_TIMEOUT_SECS to 2,
            ),
        )

        assertEquals(NetworkTuning.MIN_CONNECT_TIMEOUT_MS, tuning.connectTimeoutMs)
        assertEquals(NetworkTuning.MIN_RECEIVE_TIMEOUT_MS, tuning.receiveTimeoutMs)
    }

    @Test
    fun aboveCeiling_clampsDown() = runTest {
        val tuning = networkTuning(
            rc(
                NetworkTuning.KEY_CONNECT_TIMEOUT_SECS to 9_999,
                NetworkTuning.KEY_RECEIVE_TIMEOUT_SECS to 9_999,
            ),
        )

        assertEquals(NetworkTuning.MAX_CONNECT_TIMEOUT_MS, tuning.connectTimeoutMs)
        assertEquals(NetworkTuning.MAX_RECEIVE_TIMEOUT_MS, tuning.receiveTimeoutMs)
    }

    // Pinned deliberately: 30 s is a behaviour change from the 60 s constants this
    // replaced, chosen to match Dart's budget for the same current-state endpoint.
    // A silent drift back would re-open that split.
    @Test
    fun shippedTimeoutDefault_is30Seconds() {
        assertEquals(30_000L, NetworkTuning.DEFAULT_CONNECT_TIMEOUT_MS)
        assertEquals(30_000L, NetworkTuning.DEFAULT_RECEIVE_TIMEOUT_MS)
        assertEquals(30_000L, NetworkTuning().connectTimeoutMs)
        assertEquals(30_000L, NetworkTuning().receiveTimeoutMs)
    }

    // maxRetries is the one knob where 0 is a real value ("stop retrying" — the whole
    // point during an outage), so it must NOT share the non-positive revert rule.
    @Test
    fun zeroRetries_isHonoured_notTreatedAsUnset() = runTest {
        val tuning = networkTuning(rc(NetworkTuning.KEY_MAX_RETRIES to 0))

        assertEquals(0, tuning.maxRetries)
    }

    @Test
    fun negativeRetries_revertToTheShippedDefault() = runTest {
        val tuning = networkTuning(rc(NetworkTuning.KEY_MAX_RETRIES to -1))

        assertEquals(NetworkTuning.DEFAULT_MAX_RETRIES, tuning.maxRetries)
    }

    @Test
    fun retries_clampToTheCeiling() = runTest {
        val tuning = networkTuning(rc(NetworkTuning.KEY_MAX_RETRIES to 99))

        assertEquals(NetworkTuning.MAX_MAX_RETRIES, tuning.maxRetries)
    }

    // Backoff and debounce keys are authored in ms, not seconds — a units slip here
    // would silently turn 500 ms into 500 s.
    @Test
    fun millisKeys_areReadAsMillis_notSeconds() = runTest {
        val tuning = networkTuning(
            rc(
                NetworkTuning.KEY_RETRY_BASE_DELAY_MS to 250,
                NetworkTuning.KEY_RETRY_MAX_DELAY_MS to 8_000,
                NetworkTuning.KEY_UNAUTHORIZED_DEBOUNCE_MS to 4_000,
            ),
        )

        assertEquals(250L, tuning.retryBaseDelayMs)
        assertEquals(8_000L, tuning.retryMaxDelayMs)
        assertEquals(4_000L, tuning.unauthorizedDebounceMs)
    }

    @Test
    fun millisKeys_clampAndRevertLikeTheTimeouts() = runTest {
        val clamped = networkTuning(
            rc(
                NetworkTuning.KEY_RETRY_BASE_DELAY_MS to 1,
                NetworkTuning.KEY_UNAUTHORIZED_DEBOUNCE_MS to 999_999,
            ),
        )
        assertEquals(NetworkTuning.MIN_RETRY_BASE_DELAY_MS, clamped.retryBaseDelayMs)
        assertEquals(NetworkTuning.MAX_UNAUTHORIZED_DEBOUNCE_MS, clamped.unauthorizedDebounceMs)

        val reverted = networkTuning(rc(NetworkTuning.KEY_RETRY_BASE_DELAY_MS to 0))
        assertEquals(NetworkTuning.DEFAULT_RETRY_BASE_DELAY_MS, reverted.retryBaseDelayMs)
    }

    // The knob is only useful if an operator can tell what their value became. These
    // assert the report, not just the resolved number — a clamp that happens silently
    // is the failure this whole lever is meant to avoid.
    @Test
    fun clampsAreReported() = runTest {
        val notes = mutableListOf<String>()

        networkTuning(rc(NetworkTuning.KEY_CONNECT_TIMEOUT_SECS to 1), notes::add)

        assertEquals(1, notes.size, "expected exactly one adjustment note")
        assertTrue(NetworkTuning.KEY_CONNECT_TIMEOUT_SECS in notes[0], notes[0])
        assertTrue("clamped" in notes[0], notes[0])
    }

    @Test
    fun revertsAreReported() = runTest {
        val notes = mutableListOf<String>()

        networkTuning(rc(NetworkTuning.KEY_RECEIVE_TIMEOUT_SECS to 0), notes::add)

        assertEquals(1, notes.size)
        assertTrue("reverting" in notes[0], notes[0])
    }

    @Test
    fun retryCeilingAndRevert_areReportedSeparately() = runTest {
        val clamped = mutableListOf<String>()
        networkTuning(rc(NetworkTuning.KEY_MAX_RETRIES to 99), clamped::add)
        assertEquals(1, clamped.size)
        assertTrue("clamped" in clamped[0], clamped[0])

        val reverted = mutableListOf<String>()
        networkTuning(rc(NetworkTuning.KEY_MAX_RETRIES to -1), reverted::add)
        assertEquals(1, reverted.size)
        assertTrue("reverting" in reverted[0], reverted[0])
    }

    // Zero retries is a legitimate operator choice, not a mistake — reporting it as an
    // adjustment would train people to ignore these lines.
    @Test
    fun valuesInsideTheBand_reportNothing() = runTest {
        val notes = mutableListOf<String>()

        networkTuning(
            rc(
                NetworkTuning.KEY_CONNECT_TIMEOUT_SECS to 20,
                NetworkTuning.KEY_MAX_RETRIES to 0,
                NetworkTuning.KEY_RETRY_BASE_DELAY_MS to 750,
            ),
            notes::add,
        )

        assertEquals(emptyList(), notes)
    }

    @Test
    fun absentKeys_reportNothing() = runTest {
        val notes = mutableListOf<String>()

        networkTuning(rc(), notes::add)

        assertEquals(emptyList(), notes)
    }

    @Test
    fun store_servesShippedDefaults_beforeAnyRefresh() {
        // A request that fires before (or instead of) the launch refresh must not
        // block or read a zeroed budget.
        val store = NetworkTuningStore()

        assertEquals(NetworkTuning(), store.snapshot())
    }

    @Test
    fun store_publishesRefreshedValues() = runTest {
        val store = NetworkTuningStore()

        store.refresh(rc(NetworkTuning.KEY_CONNECT_TIMEOUT_SECS to 20))

        assertEquals(20_000L, store.snapshot().connectTimeoutMs)
        assertEquals(20_000L, store.tuning.value.connectTimeoutMs)
        assertEquals(NetworkTuning.DEFAULT_RECEIVE_TIMEOUT_MS, store.snapshot().receiveTimeoutMs)
    }
}
