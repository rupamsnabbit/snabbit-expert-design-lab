package com.snabbit.runner.shared.core.network

import io.ktor.client.network.sockets.ConnectTimeoutException
import io.ktor.client.network.sockets.SocketTimeoutException
import io.ktor.client.plugins.HttpRequestTimeoutException
import io.ktor.client.plugins.ResponseException
import kotlinx.coroutines.CancellationException

/**
 * Platform-specific tail of [NetworkExceptionMapper]. Returns null when the
 * exception isn't a known platform transport failure — the caller then
 * falls back to [AppErrorType.OTHER_ERROR].
 */
internal expect fun mapPlatformException(cause: Throwable): AppErrorType?

/**
 * Converts any transport-level [Throwable] into an [AppErrorType]
 * matching the §7.2 mapping table:
 *
 *  - Ktor timeout exceptions   -> SERVER_DOWN
 *  - Ktor [ResponseException]  -> INVALID_REQUEST (only if expectSuccess=true)
 *  - [ResponseTooLargeException] -> OTHER_ERROR
 *  - Platform-specific (JVM):  -> see androidMain actual
 *  - Anything else             -> OTHER_ERROR
 *  - [CancellationException]   -> rethrown (never mapped — structured concurrency)
 *
 * 4xx/5xx responses are handled inside `SnabbitHttpClient.execute()` and
 * turn into `Result.Err(HttpError)` — they do NOT reach this mapper.
 */
object NetworkExceptionMapper {

    fun map(cause: Throwable): AppErrorType {
        if (cause is CancellationException) throw cause

        return when (cause) {
            is HttpRequestTimeoutException,
            is ConnectTimeoutException,
            is SocketTimeoutException -> AppErrorType.SERVER_DOWN

            is ResponseException -> AppErrorType.INVALID_REQUEST

            // Mapped explicitly rather than left to the OTHER_ERROR fallback:
            // the classification is a decision (an over-sized body is neither
            // invalid input nor an unhealthy server), so it gets a test.
            is ResponseTooLargeException -> AppErrorType.OTHER_ERROR

            else -> mapPlatformException(cause) ?: AppErrorType.OTHER_ERROR
        }
    }
}
