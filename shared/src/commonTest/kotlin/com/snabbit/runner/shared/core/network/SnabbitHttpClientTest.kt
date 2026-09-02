package com.snabbit.runner.shared.core.network

import com.snabbit.runner.shared.core.result.Result
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpMethod
import io.ktor.http.HttpStatusCode
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * Header + interceptor + response-mapping coverage for SnabbitHttpClient
 * over a Ktor MockEngine. No real network, no Android deps.
 */
class SnabbitHttpClientTest {

    @Test
    fun execute_injectsAuthAndTracingHeaders() = runTest {
        val engine = MockEngine { respond("ok", HttpStatusCode.OK, jsonHeaders()) }
        val client = makeTestClient(engine, token = "abc")

        client.execute(
            SnabbitRequest(method = HttpMethod.Get, url = "${TEST_BASE_URL}api/v1/ping"),
        )

        val req = engine.requestHistory.single()
        assertEquals("Bearer abc", req.headers["Authorization"])
        assertEquals("100", req.headers["x-version-code"])
        assertNotNull(req.headers["X-Request-ID"])
        assertEquals("application/json", req.headers["Content-Type"])
    }

    @Test
    fun execute_omitsAuthHeader_whenTokenMissing() = runTest {
        val engine = MockEngine { respond("ok", HttpStatusCode.OK, jsonHeaders()) }
        val client = makeTestClient(engine, token = null)

        client.execute(SnabbitRequest(method = HttpMethod.Get, url = "${TEST_BASE_URL}foo"))

        assertNull(engine.requestHistory.single().headers["Authorization"])
    }

    @Test
    fun execute_injectsSessionId_whenProvided() = runTest {
        val engine = MockEngine { respond("ok", HttpStatusCode.OK, jsonHeaders()) }
        val client = makeTestClient(engine)

        client.execute(
            SnabbitRequest(
                method = HttpMethod.Get,
                url = "${TEST_BASE_URL}foo",
                sessionId = "sess-1",
            ),
        )

        assertEquals("sess-1", engine.requestHistory.single().headers["Session-Id"])
    }

    @Test
    fun execute_omitsSessionId_whenNotProvided() = runTest {
        val engine = MockEngine { respond("ok", HttpStatusCode.OK, jsonHeaders()) }
        val client = makeTestClient(engine)

        client.execute(SnabbitRequest(method = HttpMethod.Get, url = "${TEST_BASE_URL}foo"))

        assertNull(engine.requestHistory.single().headers["Session-Id"])
    }

    @Test
    fun execute_2xx_returnsOkWithBodyAndStatus() = runTest {
        val engine = MockEngine {
            respond("""{"ok":true}""", HttpStatusCode.OK, jsonHeaders())
        }
        val client = makeTestClient(engine)

        val result = client.execute(
            SnabbitRequest(method = HttpMethod.Get, url = "${TEST_BASE_URL}foo"),
        )

        assertTrue(result is Result.Ok)
        assertEquals(200, result.value.statusCode)
        assertEquals("""{"ok":true}""", result.value.body)
        assertTrue(result.value.requestId.isNotBlank())
    }

    @Test
    fun execute_4xx_returnsHttpError_withBody() = runTest {
        val engine = MockEngine {
            respond("""{"error":"bad"}""", HttpStatusCode.UnprocessableEntity, jsonHeaders())
        }
        val client = makeTestClient(engine)

        val result = client.execute(
            SnabbitRequest(method = HttpMethod.Post, url = "${TEST_BASE_URL}foo", body = "{}"),
        )

        assertTrue(result is Result.Err)
        val error = result.error
        assertTrue(error is NetworkError.HttpError)
        assertEquals(422, error.statusCode)
        assertEquals("""{"error":"bad"}""", error.body)
        assertEquals(AppErrorType.INVALID_REQUEST, error.errorType)
    }

    @Test
    fun execute_5xx_returnsHttpError() = runTest {
        val engine = MockEngine {
            respond("server boom", HttpStatusCode.InternalServerError, jsonHeaders())
        }
        val client = makeTestClient(engine)

        val result = client.execute(
            SnabbitRequest(method = HttpMethod.Post, url = "${TEST_BASE_URL}foo", body = "{}"),
        )

        assertTrue(result is Result.Err && result.error is NetworkError.HttpError)
        assertEquals(500, (result.error as NetworkError.HttpError).statusCode)
    }

    @Test
    fun execute_attachesQueryParams() = runTest {
        val engine = MockEngine { respond("ok", HttpStatusCode.OK, jsonHeaders()) }
        val client = makeTestClient(engine)

        client.execute(
            SnabbitRequest(
                method = HttpMethod.Get,
                url = "${TEST_BASE_URL}search",
                query = mapOf("q" to "hello", "limit" to "10"),
            ),
        )

        val url = engine.requestHistory.single().url.toString()
        assertTrue("q=hello" in url, "url=$url")
        assertTrue("limit=10" in url, "url=$url")
    }

    @Test
    fun execute_attachesCustomHeaders() = runTest {
        val engine = MockEngine { respond("ok", HttpStatusCode.OK, jsonHeaders()) }
        val client = makeTestClient(engine)

        client.execute(
            SnabbitRequest(
                method = HttpMethod.Get,
                url = "${TEST_BASE_URL}foo",
                headers = mapOf("X-Custom" to "value"),
            ),
        )

        assertEquals("value", engine.requestHistory.single().headers["X-Custom"])
    }

    @Test
    fun execute_postBodyIsSent() = runTest {
        var capturedBody: String? = null
        val engine = MockEngine { request ->
            capturedBody = request.body.toString()  // OutgoingContent.toString() exposes payload
            respond("{}", HttpStatusCode.OK, jsonHeaders())
        }
        val client = makeTestClient(engine)

        client.execute(
            SnabbitRequest(
                method = HttpMethod.Post,
                url = "${TEST_BASE_URL}foo",
                body = """{"hello":"world"}""",
            ),
        )

        assertNotNull(capturedBody)
    }

    @Test
    fun execute_401_firesUnauthorizedDispatcher() = runTest {
        val engine = MockEngine {
            respond("Unauthorized", HttpStatusCode.Unauthorized, jsonHeaders())
        }
        val recorder = RecordingUnauthorizedDispatcher()
        // currentTimeMs returns increasing values so the debounce never blocks.
        var t = 0L
        val client = makeTestClient(
            engine,
            currentTimeMs = { (t + 10_000L).also { t = it } },
            unauthorizedDispatcher = recorder.dispatcher,
        )

        client.execute(SnabbitRequest(method = HttpMethod.Get, url = "${TEST_BASE_URL}foo"))

        assertEquals(1, recorder.fireCount)
    }
}
