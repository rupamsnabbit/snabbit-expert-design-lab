package com.snabbit.runner.shared.core.network

import com.snabbit.runner.shared.core.result.Result
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.network.sockets.ConnectTimeoutException
import io.ktor.client.plugins.HttpRequestTimeoutException
import io.ktor.http.HttpMethod
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertTrue

/**
 * Transport-error and cancellation behaviour for SnabbitHttpClient.
 *
 * We inject exceptions directly through MockEngine (rather than relying on
 * the real HttpTimeout plugin, which runTest's virtual-time scheduler can
 * trigger spuriously). This exercises the NetworkExceptionMapper path
 * and the CancellationException rethrow.
 */
class SnabbitHttpClientErrorTest {

    @Test
    fun execute_httpRequestTimeout_mapsTo_SERVER_DOWN() = runTest {
        val engine = MockEngine { throw HttpRequestTimeoutException("https://test", 1_000L) }
        val client = makeTestClient(engine)

        val result = client.execute(
            SnabbitRequest(method = HttpMethod.Get, url = "${TEST_BASE_URL}foo"),
        )

        assertTrue(result is Result.Err && result.error is NetworkError.TransportError)
        assertEquals(
            AppErrorType.SERVER_DOWN,
            (result.error as NetworkError.TransportError).errorType,
        )
    }

    @Test
    fun execute_ktorConnectTimeout_mapsTo_SERVER_DOWN() = runTest {
        val engine = MockEngine { throw ConnectTimeoutException("https://test", null) }
        val client = makeTestClient(engine)

        val result = client.execute(
            SnabbitRequest(method = HttpMethod.Get, url = "${TEST_BASE_URL}foo"),
        )

        assertEquals(
            AppErrorType.SERVER_DOWN,
            ((result as Result.Err).error as NetworkError.TransportError).errorType,
        )
    }

    @Test
    fun execute_unknownHost_mapsTo_NO_INTERNET() = runTest {
        val engine = MockEngine { throw java.net.UnknownHostException("api.example.com") }
        val client = makeTestClient(engine)

        val result = client.execute(
            SnabbitRequest(method = HttpMethod.Get, url = "${TEST_BASE_URL}foo"),
        )

        assertEquals(
            AppErrorType.NO_INTERNET,
            ((result as Result.Err).error as NetworkError.TransportError).errorType,
        )
    }

    @Test
    fun execute_sslException_mapsTo_SECURITY_ERROR() = runTest {
        val engine = MockEngine { throw javax.net.ssl.SSLException("bad cert") }
        val client = makeTestClient(engine)

        val result = client.execute(
            SnabbitRequest(method = HttpMethod.Get, url = "${TEST_BASE_URL}foo"),
        )

        assertEquals(
            AppErrorType.SECURITY_ERROR,
            ((result as Result.Err).error as NetworkError.TransportError).errorType,
        )
    }

    @Test
    fun execute_unknownException_mapsTo_OTHER_ERROR() = runTest {
        val engine = MockEngine { throw IllegalStateException("???") }
        val client = makeTestClient(engine)

        val result = client.execute(
            SnabbitRequest(method = HttpMethod.Get, url = "${TEST_BASE_URL}foo"),
        )

        assertEquals(
            AppErrorType.OTHER_ERROR,
            ((result as Result.Err).error as NetworkError.TransportError).errorType,
        )
    }

    @Test
    fun execute_cancellation_isRethrown_notMapped() = runTest {
        val engine = MockEngine { throw CancellationException("cancelled") }
        val client = makeTestClient(engine)

        assertFailsWith<CancellationException> {
            client.execute(
                SnabbitRequest(method = HttpMethod.Get, url = "${TEST_BASE_URL}foo"),
            )
        }
    }
}
