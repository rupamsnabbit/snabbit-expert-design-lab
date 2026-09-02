package com.snabbit.runner.shared.core.network

/**
 * Successful HTTP response (status 2xx). Body is returned as a raw string
 * so callers control deserialization with the types they own.
 *
 * `requestId` and `durationMs` aid log/crash correlation. See §2.3.
 */
data class SuccessResponse(
    val statusCode: Int,
    val body: String,
    val headers: Map<String, List<String>>,
    val requestId: String,
    val durationMs: Long,
)

/**
 * Failure outcome from `SnabbitHttpClient.execute()`. The split is
 * deliberate: callers handle a server-rendered error (HttpError, body has
 * detail) differently from a transport failure (TransportError, nothing
 * to show but a generic message). See §2.3.
 */
sealed class NetworkError {
    /** Server responded with 4xx/5xx — `body` may carry validation detail. */
    data class HttpError(
        val statusCode: Int,
        val body: String,
        val errorType: AppErrorType,
        val requestId: String,
        val durationMs: Long,
    ) : NetworkError()

    /** No HTTP response received (no internet, timeout, SSL failure). */
    data class TransportError(
        val errorType: AppErrorType,
        val requestId: String,
        val durationMs: Long,
    ) : NetworkError()
}

/**
 * The response body breached [SnabbitHttpClientImpl.DEFAULT_MAX_RESPONSE_BYTES]
 * (or the injected override) and was abandoned without being materialized.
 *
 * Internal on purpose — no caller ever sees it. `execute()` throws it from its
 * capped body read and its own `catch` turns it into
 * `TransportError(AppErrorType.OTHER_ERROR)`: the server did respond, but we
 * hold nothing usable, which is neither "your input was invalid" nor "the
 * server is down".
 *
 * @property declaredBytes the `Content-Length` the server advertised, or null
 *   when the response was chunked and the ceiling was hit mid-stream.
 */
internal class ResponseTooLargeException(
    val declaredBytes: Long?,
    val maxBytes: Long,
) : Exception(
    "Response body exceeds the $maxBytes-byte ceiling " +
        (declaredBytes?.let { "(Content-Length: $it)" } ?: "(chunked, no Content-Length)"),
)
