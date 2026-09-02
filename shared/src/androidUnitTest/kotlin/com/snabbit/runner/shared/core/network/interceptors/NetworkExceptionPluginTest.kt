package com.snabbit.runner.shared.core.network.interceptors

import com.snabbit.runner.shared.core.CrashReporter
import com.snabbit.runner.shared.core.network.SnabbitRequest
import com.snabbit.runner.shared.core.network.TEST_BASE_URL
import com.snabbit.runner.shared.core.network.makeTestClient
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpMethod
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.test.runTest
import java.io.IOException
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

/**
 * Verifies the crash-reporter pathway through NetworkExceptionPlugin —
 * the default test rig passes `crashReporter = null`, so without this
 * suite a regression that silently dropped the reporter call would be
 * invisible.
 */
class NetworkExceptionPluginTest {

    @Test
    fun crashReporter_fires_withUrlAndMethod_onTransportException() = runTest {
        val captured = mutableListOf<Pair<Throwable, Map<String, String>>>()
        val reporter = CrashReporter { t, ctx ->
            captured += t to ctx
        }
        val engine = MockEngine { throw IOException("boom") }
        val client = makeTestClient(engine, crashReporter = reporter)

        client.execute(
            SnabbitRequest(method = HttpMethod.Get, url = "${TEST_BASE_URL}foo"),
        )

        assertEquals(1, captured.size, "crashReporter must be invoked exactly once")
        assertTrue(captured[0].first is IOException)
        assertEquals("GET", captured[0].second["method"])
        val url = captured[0].second["url"]
        assertNotNull(url)
        assertTrue(url!!.contains("foo"), "url context should contain the request path, got $url")
    }

    @Test
    fun crashReporter_doesNotFire_onSuccessfulResponse() = runTest {
        val captured = mutableListOf<Throwable>()
        val reporter = CrashReporter { t, _ -> captured += t }
        val engine = MockEngine {
            respond("ok", HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
        }
        val client = makeTestClient(engine, crashReporter = reporter)

        client.execute(SnabbitRequest(method = HttpMethod.Get, url = "${TEST_BASE_URL}foo"))

        assertEquals(0, captured.size, "crashReporter must NOT fire on 2xx responses")
    }

    @Test
    fun crashReporter_doesNotFire_onHttpErrorResponses() = runTest {
        // 4xx/5xx responses are "the server replied" — not a transport
        // failure. The reporter is for actual exceptions only.
        val captured = mutableListOf<Throwable>()
        val reporter = CrashReporter { t, _ -> captured += t }
        val engine = MockEngine {
            respond(
                "server boom",
                HttpStatusCode.InternalServerError,
                headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val client = makeTestClient(engine, crashReporter = reporter)

        client.execute(SnabbitRequest(method = HttpMethod.Get, url = "${TEST_BASE_URL}foo"))

        assertEquals(0, captured.size, "crashReporter must NOT fire on 4xx/5xx responses")
    }

    @Test
    fun cancellationException_isRethrown_andNotReported() = runTest {
        // Structured concurrency: cancellations propagate untouched and
        // are NOT funnelled into the crash reporter.
        val captured = mutableListOf<Throwable>()
        val reporter = CrashReporter { t, _ -> captured += t }
        val engine = MockEngine { throw CancellationException("cancelled") }
        val client = makeTestClient(engine, crashReporter = reporter)

        assertFailsWith<CancellationException> {
            client.execute(SnabbitRequest(method = HttpMethod.Get, url = "${TEST_BASE_URL}foo"))
        }
        assertEquals(0, captured.size, "CancellationException must skip the reporter")
    }
}
