package com.snabbit.runner.shared.core.network

import java.net.ConnectException
import java.net.SocketTimeoutException
import java.net.UnknownHostException
import javax.net.ssl.SSLException

/**
 * JVM-specific exception → [AppErrorType] mapping (§7.2).
 *
 * Order of branches matters only between `SSLException`/`UnknownHostException`/
 * `ConnectException` (all extend `IOException`) and the missing
 * catch-all — there is no catch-all on purpose:
 *
 *  - [SocketTimeoutException] → [AppErrorType.SERVER_DOWN]
 *    Server reachable but slow / unresponsive.
 *
 *  - [SSLException]           → [AppErrorType.SECURITY_ERROR]
 *    TLS handshake failure, expired cert, hostname mismatch, pinning
 *    violation, potential MITM. **Never** `INVALID_REQUEST` — it's a
 *    transport-security signal, not user-input invalidity.
 *
 *  - [UnknownHostException]   → [AppErrorType.NO_INTERNET]
 *    DNS resolution failed — device is almost certainly offline.
 *
 *  - [ConnectException]       → [AppErrorType.SERVER_DOWN]
 *    DNS resolved, IP routable, server refused or port unreachable. The
 *    user is online; **our** server is the problem. Distinct from
 *    `NO_INTERNET` so we don't send users to "check your connection"
 *    when the real issue is upstream.
 *
 *  - Everything else (including unrecognised [java.io.IOException]
 *    subtypes like `EOFException`, file/stream failures) → `null`,
 *    which the upstream mapper turns into `AppErrorType.OTHER_ERROR`.
 *    No blanket `IOException → NO_INTERNET` — it lied to users whenever
 *    a non-network IOException slipped through (parser EOF, etc.).
 */
internal actual fun mapPlatformException(cause: Throwable): AppErrorType? = when (cause) {
    is SocketTimeoutException -> AppErrorType.SERVER_DOWN
    is SSLException -> AppErrorType.SECURITY_ERROR
    is UnknownHostException -> AppErrorType.NO_INTERNET
    is ConnectException -> AppErrorType.SERVER_DOWN
    else -> null
}
