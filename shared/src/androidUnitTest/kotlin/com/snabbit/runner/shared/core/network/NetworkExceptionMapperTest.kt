package com.snabbit.runner.shared.core.network

import io.ktor.client.network.sockets.ConnectTimeoutException
import io.ktor.client.network.sockets.SocketTimeoutException as KtorSocketTimeoutException
import io.ktor.client.plugins.HttpRequestTimeoutException
import kotlinx.coroutines.CancellationException
import java.io.EOFException
import java.net.ConnectException
import java.net.SocketTimeoutException
import java.net.UnknownHostException
import javax.net.ssl.SSLException
import javax.net.ssl.SSLHandshakeException
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNull

class NetworkExceptionMapperTest {

    // -- Ktor (commonMain) timeout family -> SERVER_DOWN ---------------
    //
    // Constructors take (message, cause) — we don't need real wire state,
    // just an instance of the right type to drive the `when` branch.

    @Test
    fun httpRequestTimeout_mapsTo_SERVER_DOWN() {
        val ex = HttpRequestTimeoutException("https://example.com", 1000L)
        assertEquals(AppErrorType.SERVER_DOWN, NetworkExceptionMapper.map(ex))
    }

    @Test
    fun ktorConnectTimeout_mapsTo_SERVER_DOWN() {
        val ex = ConnectTimeoutException("https://example.com", null)
        assertEquals(AppErrorType.SERVER_DOWN, NetworkExceptionMapper.map(ex))
    }

    @Test
    fun ktorSocketTimeout_mapsTo_SERVER_DOWN() {
        val ex = KtorSocketTimeoutException("https://example.com", null)
        assertEquals(AppErrorType.SERVER_DOWN, NetworkExceptionMapper.map(ex))
    }

    // -- JVM platform exceptions (androidMain actual) ------------------

    @Test
    fun unknownHostException_mapsTo_NO_INTERNET() {
        // DNS resolution failed → device is almost certainly offline.
        assertEquals(AppErrorType.NO_INTERNET, NetworkExceptionMapper.map(UnknownHostException("nope")))
    }

    @Test
    fun connectException_mapsTo_SERVER_DOWN() {
        // DNS resolved, IP routable, server refused or port unreachable.
        // User is online; our server is the problem. Distinct from
        // NO_INTERNET so we don't send users to "check your connection".
        assertEquals(AppErrorType.SERVER_DOWN, NetworkExceptionMapper.map(ConnectException("refused")))
    }

    @Test
    fun rawSocketTimeoutException_mapsTo_SERVER_DOWN() {
        assertEquals(AppErrorType.SERVER_DOWN, NetworkExceptionMapper.map(SocketTimeoutException("read")))
    }

    @Test
    fun sslException_mapsTo_SECURITY_ERROR() {
        // Transport-security signal — not user-input invalidity.
        assertEquals(AppErrorType.SECURITY_ERROR, NetworkExceptionMapper.map(SSLException("cert")))
    }

    @Test
    fun sslHandshakeException_mapsTo_SECURITY_ERROR() {
        assertEquals(
            AppErrorType.SECURITY_ERROR,
            NetworkExceptionMapper.map(SSLHandshakeException("bad handshake")),
        )
    }

    @Test
    fun otherIOException_mapsTo_OTHER_ERROR() {
        // No blanket IOException → NO_INTERNET. A non-network IOException
        // (file read, stream close) should NOT be reported to the user as
        // "device is offline".
        assertEquals(
            AppErrorType.OTHER_ERROR,
            NetworkExceptionMapper.map(java.io.IOException("misc")),
        )
    }

    @Test
    fun eofException_doesNotFalselyMapTo_NO_INTERNET() {
        // Regression guard for the reviewer's concern: EOFException is a
        // very common IOException subtype (parser end-of-stream, truncated
        // body) — used to surface as "no internet" under the old blanket
        // mapping. Must fall through to OTHER_ERROR.
        assertEquals(
            AppErrorType.OTHER_ERROR,
            NetworkExceptionMapper.map(EOFException("unexpected end of stream")),
        )
    }

    // -- Response-size ceiling ----------------------------------------

    @Test
    fun responseTooLarge_mapsTo_OTHER_ERROR() {
        // An over-sized body is neither invalid user input (INVALID_REQUEST)
        // nor an unhealthy server (SERVER_DOWN) — the server answered, we just
        // hold nothing usable. Mapped explicitly so the classification is
        // pinned rather than riding the fallback.
        assertEquals(
            AppErrorType.OTHER_ERROR,
            NetworkExceptionMapper.map(
                ResponseTooLargeException(declaredBytes = 42_000_000L, maxBytes = 10L * 1024 * 1024),
            ),
        )
    }

    @Test
    fun responseTooLarge_chunked_mapsTo_OTHER_ERROR() {
        // Same classification when the server declared no Content-Length and
        // the ceiling was hit mid-stream.
        assertEquals(
            AppErrorType.OTHER_ERROR,
            NetworkExceptionMapper.map(
                ResponseTooLargeException(declaredBytes = null, maxBytes = 10L * 1024 * 1024),
            ),
        )
    }

    // -- Fallback ------------------------------------------------------

    @Test
    fun unknownThrowable_mapsTo_OTHER_ERROR() {
        assertEquals(
            AppErrorType.OTHER_ERROR,
            NetworkExceptionMapper.map(IllegalStateException("???")),
        )
    }

    // -- CancellationException is rethrown, never mapped --------------

    @Test
    fun cancellation_isRethrown_notMapped() {
        assertFailsWith<CancellationException> {
            NetworkExceptionMapper.map(CancellationException("cancelled"))
        }
    }

    // -- mapPlatformException returns null for unknown types ----------

    @Test
    fun platformMapper_returnsNull_forNonPlatformException() {
        assertNull(mapPlatformException(IllegalStateException("nope")))
    }
}
