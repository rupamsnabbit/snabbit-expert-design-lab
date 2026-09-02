package com.snabbit.runner.shared.core.network

import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpMethod
import io.ktor.http.HttpStatusCode
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals

/**
 * The RC-driven retry limit actually governs attempt count.
 *
 * This is the knob with the least obvious implementation: Ktor reads
 * `HttpRequestRetry.maxRetries` once at install time, and Koin holds the client as
 * a process-lived `single`, so the plugin is installed with the *ceiling* and the
 * live limit is enforced inside `retryIf`. That indirection is exactly the kind of
 * thing that silently off-by-ones, so every limit from 0 to the ceiling is pinned
 * here by observed attempt count rather than by reading the predicate.
 *
 * `runTest` skips the backoff `delay(...)`, so these complete instantly.
 */
class SnabbitHttpClientRetryTuningTest {

    private fun alwaysUnavailable(counter: () -> Unit) = MockEngine {
        counter()
        respond("down", HttpStatusCode.ServiceUnavailable, jsonHeaders())
    }

    private suspend fun attemptsFor(maxRetries: Int): Int {
        var attempts = 0
        val client = makeTestClient(
            alwaysUnavailable { attempts++ },
            networkTuning = NetworkTuning(maxRetries = maxRetries),
        )

        client.execute(SnabbitRequest(method = HttpMethod.Get, url = "${TEST_BASE_URL}foo"))

        return attempts
    }

    // The incident posture: a failing gateway should stop being hammered. If this
    // regressed to "1 retry" the knob would be useless for the case it exists for.
    @Test
    fun zeroRetries_sendsExactlyOneAttempt() = runTest {
        assertEquals(1, attemptsFor(0))
    }

    @Test
    fun oneRetry_sendsTwoAttempts() = runTest {
        assertEquals(2, attemptsFor(1))
    }

    @Test
    fun shippedDefault_stillSendsThreeAttempts() = runTest {
        assertEquals(3, attemptsFor(NetworkTuning.DEFAULT_MAX_RETRIES))
    }

    @Test
    fun ceiling_sendsCeilingPlusOneAttempts() = runTest {
        // The plugin is installed at this exact number, so this case also proves the
        // predicate is not silently capping BELOW Ktor's own limit.
        assertEquals(
            NetworkTuning.MAX_MAX_RETRIES + 1,
            attemptsFor(NetworkTuning.MAX_MAX_RETRIES),
        )
    }

    @Test
    fun postIsStillNeverRetried_whateverTheLimit() = runTest {
        var attempts = 0
        val client = makeTestClient(
            alwaysUnavailable { attempts++ },
            networkTuning = NetworkTuning(maxRetries = NetworkTuning.MAX_MAX_RETRIES),
        )

        client.execute(
            SnabbitRequest(method = HttpMethod.Post, url = "${TEST_BASE_URL}foo", body = "{}"),
        )

        assertEquals(1, attempts, "§5.4 — POST is never retried, regardless of the RC limit")
    }
}
