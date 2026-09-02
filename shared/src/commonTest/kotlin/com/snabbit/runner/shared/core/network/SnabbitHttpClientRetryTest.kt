package com.snabbit.runner.shared.core.network

import com.snabbit.runner.shared.core.result.Result
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpMethod
import io.ktor.http.HttpStatusCode
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * Retry behaviour for SnabbitHttpClient (§5). HttpRequestRetry delays use
 * `delay(...)`, which runTest's virtual-time scheduler skips — so these
 * tests complete instantly even though the production backoff is up to 5s.
 */
class SnabbitHttpClientRetryTest {

    @Test
    fun execute_retries503_succeedsOn3rdAttempt() = runTest {
        var attempts = 0
        val engine = MockEngine {
            attempts++
            if (attempts < 3) {
                respond("retrying", HttpStatusCode.ServiceUnavailable, jsonHeaders())
            } else {
                respond("ok", HttpStatusCode.OK, jsonHeaders())
            }
        }
        val client = makeTestClient(engine)

        val result = client.execute(
            SnabbitRequest(method = HttpMethod.Get, url = "${TEST_BASE_URL}foo"),
        )

        assertTrue(result is Result.Ok)
        assertEquals(200, result.value.statusCode)
        assertEquals(3, attempts, "expected 1 original + 2 retries")
    }

    @Test
    fun execute_retriesExhausted_returnsLastHttpError() = runTest {
        var attempts = 0
        val engine = MockEngine {
            attempts++
            respond("still down", HttpStatusCode.ServiceUnavailable, jsonHeaders())
        }
        val client = makeTestClient(engine)

        val result = client.execute(
            SnabbitRequest(method = HttpMethod.Get, url = "${TEST_BASE_URL}foo"),
        )

        assertTrue(result is Result.Err && result.error is NetworkError.HttpError)
        assertEquals(503, (result.error as NetworkError.HttpError).statusCode)
        assertEquals(3, attempts, "maxRetries=2 means 1 original + 2 retries = 3 attempts")
    }

    @Test
    fun execute_post_doesNotRetry_on503() = runTest {
        var attempts = 0
        val engine = MockEngine {
            attempts++
            respond("nope", HttpStatusCode.ServiceUnavailable, jsonHeaders())
        }
        val client = makeTestClient(engine)

        val result = client.execute(
            SnabbitRequest(
                method = HttpMethod.Post,
                url = "${TEST_BASE_URL}foo",
                body = "{}",
            ),
        )

        assertTrue(result is Result.Err && result.error is NetworkError.HttpError)
        assertEquals(503, (result.error as NetworkError.HttpError).statusCode)
        assertEquals(1, attempts, "POST is not retried — §5.4")
    }

    @Test
    fun execute_500_isNotRetried() = runTest {
        // §5: retry covers 502/503/504 only. 500 is a hard server error.
        var attempts = 0
        val engine = MockEngine {
            attempts++
            respond("boom", HttpStatusCode.InternalServerError, jsonHeaders())
        }
        val client = makeTestClient(engine)

        client.execute(SnabbitRequest(method = HttpMethod.Get, url = "${TEST_BASE_URL}foo"))

        assertEquals(1, attempts)
    }

    @Test
    fun execute_4xx_isNotRetried() = runTest {
        var attempts = 0
        val engine = MockEngine {
            attempts++
            respond("nope", HttpStatusCode.UnprocessableEntity, jsonHeaders())
        }
        val client = makeTestClient(engine)

        client.execute(SnabbitRequest(method = HttpMethod.Get, url = "${TEST_BASE_URL}foo"))

        assertEquals(1, attempts)
    }
}
