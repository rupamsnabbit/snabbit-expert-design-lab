package com.snabbit.runner.shared.core.network

import com.snabbit.runner.shared.core.result.Result
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.Headers
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpMethod
import io.ktor.http.HttpStatusCode
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * Response-size ceiling for SnabbitHttpClient (§4.2 of the AWoL / delayed
 * check-in network audit).
 *
 * Every timeout in the client bounds *time*; none bounded *size* — the old
 * `bodyAsText()` buffered whatever the peer sent. `execute()` now caps it,
 * honouring `Content-Length` when the server declares one and bounding the
 * read itself when it does not.
 *
 * The ceiling is constructor-injected (production default: 10 MiB) so these
 * run against a handful of bytes instead of a multi-megabyte fixture.
 */
class SnabbitHttpClientBodyLimitTest {

    /** Tiny stand-in for the production [SnabbitHttpClientImpl.DEFAULT_MAX_RESPONSE_BYTES]. */
    private val ceiling = 32L

    /** [n] ASCII characters — one byte each once UTF-8 encoded. */
    private fun body(n: Int) = "x".repeat(n)

    private fun headersWithContentLength(length: String) = Headers.build {
        append(HttpHeaders.ContentType, "application/json")
        append(HttpHeaders.ContentLength, length)
    }

    @Test
    fun execute_bodyExactlyAtCeiling_isAccepted() = runTest {
        // The boundary is inclusive: at the limit is fine, over it is not.
        val payload = body(ceiling.toInt())
        val engine = MockEngine { respond(payload, HttpStatusCode.OK, jsonHeaders()) }
        val client = makeTestClient(engine, maxResponseBytes = ceiling)

        val result = client.execute(
            SnabbitRequest(method = HttpMethod.Get, url = "${TEST_BASE_URL}foo"),
        )

        assertTrue(result is Result.Ok)
        assertEquals(payload, result.value.body)
    }

    @Test
    fun execute_chunkedBodyOverCeiling_returnsTransportError() = runTest {
        // jsonHeaders() carries no Content-Length, so this is the streaming
        // guard: nothing declared the size, the read itself has to cap.
        val engine = MockEngine {
            respond(body(ceiling.toInt() + 1), HttpStatusCode.OK, jsonHeaders())
        }
        val client = makeTestClient(engine, maxResponseBytes = ceiling)

        val result = client.execute(
            SnabbitRequest(method = HttpMethod.Get, url = "${TEST_BASE_URL}foo"),
        )

        assertTrue(result is Result.Err, "over-sized chunked body must not surface as Ok")
        val error = result.error
        assertTrue(error is NetworkError.TransportError, "expected TransportError, got $error")
        assertEquals(AppErrorType.OTHER_ERROR, error.errorType)
    }

    @Test
    fun execute_declaredContentLengthOverCeiling_isRejectedWithoutReadingBody() = runTest {
        // The declared size alone rejects: the channel here holds four bytes,
        // so an Err can only have come from the Content-Length check.
        val engine = MockEngine {
            respond("tiny", HttpStatusCode.OK, headersWithContentLength("999999"))
        }
        val client = makeTestClient(engine, maxResponseBytes = ceiling)

        val result = client.execute(
            SnabbitRequest(method = HttpMethod.Get, url = "${TEST_BASE_URL}foo"),
        )

        assertTrue(result is Result.Err, "a declared over-sized body must be refused up front")
        val error = result.error
        assertTrue(error is NetworkError.TransportError, "expected TransportError, got $error")
        assertEquals(AppErrorType.OTHER_ERROR, error.errorType)
    }

    @Test
    fun execute_declaredContentLengthAtCeiling_isAccepted() = runTest {
        val payload = body(ceiling.toInt())
        val engine = MockEngine {
            respond(payload, HttpStatusCode.OK, headersWithContentLength(ceiling.toString()))
        }
        val client = makeTestClient(engine, maxResponseBytes = ceiling)

        val result = client.execute(
            SnabbitRequest(method = HttpMethod.Get, url = "${TEST_BASE_URL}foo"),
        )

        assertTrue(result is Result.Ok)
        assertEquals(payload, result.value.body)
    }

    @Test
    fun execute_errorResponseOverCeiling_isAlsoCapped() = runTest {
        // Not a 2xx-only rule — a gateway's endless HTML error page is exactly
        // the payload that motivated the ceiling. 500 (not 502) so the retry
        // policy stays out of this assertion.
        val engine = MockEngine {
            respond(body(ceiling.toInt() + 1), HttpStatusCode.InternalServerError, jsonHeaders())
        }
        val client = makeTestClient(engine, maxResponseBytes = ceiling)

        val result = client.execute(
            SnabbitRequest(method = HttpMethod.Get, url = "${TEST_BASE_URL}foo"),
        )

        assertTrue(result is Result.Err && result.error is NetworkError.TransportError)
    }

    @Test
    fun execute_401OverCeiling_stillFiresUnauthorizedDispatcher() = runTest {
        // The observer is notified on the STATUS, before the body is read: a
        // 401 whose body we refuse to buffer must still log the runner out.
        val engine = MockEngine {
            respond(body(ceiling.toInt() + 1), HttpStatusCode.Unauthorized, jsonHeaders())
        }
        val recorder = RecordingUnauthorizedDispatcher()
        var t = 0L
        val client = makeTestClient(
            engine,
            currentTimeMs = { (t + 10_000L).also { t = it } },
            unauthorizedDispatcher = recorder.dispatcher,
            maxResponseBytes = ceiling,
        )

        val result = client.execute(
            SnabbitRequest(method = HttpMethod.Get, url = "${TEST_BASE_URL}foo"),
        )

        assertEquals(1, recorder.fireCount, "401 must dispatch even with an unreadable body")
        assertTrue(result is Result.Err && result.error is NetworkError.TransportError)
    }

    @Test
    fun execute_overCeiling_isNotRetried() = runTest {
        // The ceiling is enforced after the send pipeline returns, so it must
        // never feed HttpRequestRetry — one attempt, one rejection.
        var attempts = 0
        val engine = MockEngine {
            attempts++
            respond(body(ceiling.toInt() + 1), HttpStatusCode.OK, jsonHeaders())
        }
        val client = makeTestClient(engine, maxResponseBytes = ceiling)

        client.execute(SnabbitRequest(method = HttpMethod.Get, url = "${TEST_BASE_URL}foo"))

        assertEquals(1, attempts)
    }
}
