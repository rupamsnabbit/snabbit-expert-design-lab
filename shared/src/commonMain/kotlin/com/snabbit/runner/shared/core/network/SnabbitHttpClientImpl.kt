package com.snabbit.runner.shared.core.network

import com.snabbit.runner.shared.core.CurrentTimeMs
import com.snabbit.runner.shared.core.Logger
import com.snabbit.runner.shared.core.network.interceptors.AuthInterceptor
import com.snabbit.runner.shared.core.network.interceptors.RequestInterceptor
import com.snabbit.runner.shared.core.network.interceptors.UnauthorizedResponseObserver
import com.snabbit.runner.shared.core.result.Result
import io.ktor.client.HttpClient
import io.ktor.client.plugins.timeout
import io.ktor.client.request.forms.MultiPartFormDataContent
import io.ktor.client.request.forms.formData
import io.ktor.client.request.parameter
import io.ktor.client.request.request
import io.ktor.client.request.setBody
import io.ktor.client.statement.HttpResponse
import io.ktor.client.statement.bodyAsChannel
import io.ktor.http.Headers
import io.ktor.http.HttpHeaders
import io.ktor.http.charset
import io.ktor.http.contentLength
import io.ktor.http.takeFrom
import io.ktor.utils.io.cancel
import io.ktor.utils.io.charsets.Charsets
import io.ktor.utils.io.core.readText
import io.ktor.utils.io.core.remaining
import io.ktor.utils.io.readRemaining
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.withTimeoutOrNull

private const val TAG = "SnabbitHttp"

/**
 * Production [SnabbitHttpClient] backed by a Ktor [HttpClient] (§2, §7, §13).
 *
 * Composes the Ktor client with our interceptors and translates the
 * Ktor-side outcome into a [Result] of [SuccessResponse] / [NetworkError].
 * Construction lives in [buildKtorClient]; tests build their own via the
 * same factory with a `MockEngine`.
 */
class SnabbitHttpClientImpl(
    private val httpClient: HttpClient,
    private val networkConfigStore: NetworkConfigStore,
    /**
     * Supplies the app-wide, Remote-Config-driven timeout budget used by any
     * request that doesn't pin its own. Read non-suspending per call — see
     * [NetworkTuningStore.snapshot].
     */
    private val networkTuningStore: NetworkTuningStore,
    private val authInterceptor: AuthInterceptor,
    private val requestInterceptor: RequestInterceptor,
    private val unauthorizedObserver: UnauthorizedResponseObserver,
    private val logger: Logger,
    private val currentTimeMs: CurrentTimeMs,
    /**
     * Client-wide ceiling on a single response body, in bytes. Must be
     * positive; see [DEFAULT_MAX_RESPONSE_BYTES] for why the default is what
     * it is. Injectable so tests can drive the limit without materializing a
     * multi-megabyte fixture.
     */
    private val maxResponseBytes: Long = DEFAULT_MAX_RESPONSE_BYTES,
) : SnabbitHttpClient {

    /** Private on purpose — see [SnabbitHttpClient.execute]'s KDoc. */
    private suspend fun awaitNetworkConfig(): NetworkConfig = networkConfigStore.awaitReady()

    override suspend fun execute(request: SnabbitRequest): Result<SuccessResponse, NetworkError> {
        val startMs = currentTimeMs()
        var requestId = ""

        // Never log the raw URL: job/penalty ids, phone numbers and query values ride
        // in it, and the warn/error lines below still reach logcat on release builds.
        val logUrl = redactUrlForLog(request.url)

        // Resolved ONCE, here, so the cold-start gates below and the socket
        // timeouts further down share one budget for this call. Snapshotting up
        // front also means a mid-flight RC refresh can't move the goalposts
        // between the gate and the request.
        val tuning = networkTuningStore.snapshot()
        val connectTimeoutMs = request.connectTimeoutMs ?: tuning.connectTimeoutMs
        val receiveTimeoutMs = request.receiveTimeoutMs ?: tuning.receiveTimeoutMs

        // Cold-start gates: block until baseUrl and token hydration are ready,
        // but bounded by the connect budget so a never-arriving config/token
        // fails the request instead of hanging the (process-lived) caller — e.g.
        // an overlay Accept fired from a force-killed process. Warm path returns
        // immediately.
        val config = withTimeoutOrNull(connectTimeoutMs) { awaitNetworkConfig() }
            ?: return coldGateError(requestId, startMs)
        val baseUrl = config.baseUrl
        // Resolved HERE, inside the bounded gate, rather than by the caller: a data
        // source that awaited the config itself would sit on an unbounded
        // `first { … }` outside this timeout and could hang forever.
        val resolvedUrl = request.resolveUrl(config)

        var token: String? = null
        val tokenReady = withTimeoutOrNull(connectTimeoutMs) {
            token = authInterceptor.resolveToken()
            true
        }
        // Distinguish a wedged hydration (timeout) from a genuinely logged-out
        // user (token == null once hydration completed): only the former fails
        // here, so a request we *expected* to be authed never goes out unauthed.
        if (tokenReady == null) return coldGateError(requestId, startMs)

        return try {
            // Built BEFORE `httpClient.request { }` on purpose. Ktor materializes the
            // body inside that (non-suspend) builder lambda, on the caller's
            // dispatcher — and shift-login's chain runs on Main. Reading a selfie
            // there blocks the UI thread, so the file I/O happens here, in a suspend
            // context that `readFileBytes` can hop off Main from.
            val multipart = request.formParts?.let { buildMultipart(it) }

            val response = httpClient.request {
                method = request.method
                url.takeFrom(resolvedUrl)
                request.query.forEach { (k, v) -> parameter(k, v) }
                request.headers.forEach { (k, v) -> headers.append(k, v) }

                authInterceptor.applyTo(this, request, token)
                requestId = requestInterceptor.applyTo(
                    builder = this,
                    method = request.method.value,
                    baseUrl = baseUrl,
                    isMultipart = multipart != null,
                )

                when {
                    multipart != null -> setBody(multipart)
                    request.body != null -> setBody(request.body)
                }

                timeout {
                    connectTimeoutMillis = connectTimeoutMs
                    requestTimeoutMillis = receiveTimeoutMs
                    socketTimeoutMillis = receiveTimeoutMs
                }
            }

            val durationMs = currentTimeMs() - startMs
            val statusCode = response.status.value
            val headersMap: Map<String, List<String>> =
                response.headers.entries().associate { it.key to it.value }

            // Fired on the STATUS, before the body is read: a 401 must still
            // log the runner out even when its body is unreadable (over the
            // ceiling, or a broken connection mid-body).
            unauthorizedObserver.notifyResponse(statusCode)

            val body = readBodyCapped(response)

            if (statusCode in 200..299) {
                logger.d(TAG, "${request.method.value} $logUrl -> $statusCode in ${durationMs}ms")
                Result.Ok(
                    SuccessResponse(
                        statusCode = statusCode,
                        body = body,
                        headers = headersMap,
                        requestId = requestId,
                        durationMs = durationMs,
                    ),
                )
            } else {
                logger.w(TAG, "${request.method.value} $logUrl -> $statusCode in ${durationMs}ms")
                // Separate 4xx (client / invalid request) from 5xx (server
                // unhealthy) so callers can branch — a "Try again later"
                // toast for 5xx vs a "Please re-check your input" surface
                // for 4xx. A 422 is still INVALID_REQUEST under this
                // bucketing; refine in the future if a feature needs to
                // distinguish further.
                Result.Err(
                    NetworkError.HttpError(
                        statusCode = statusCode,
                        body = body,
                        errorType = when (statusCode) {
                            in 400..499 -> AppErrorType.INVALID_REQUEST
                            in 500..599 -> AppErrorType.SERVER_DOWN
                            else -> AppErrorType.OTHER_ERROR
                        },
                        requestId = requestId,
                        durationMs = durationMs,
                    ),
                )
            }
        } catch (e: CancellationException) {
            throw e
        } catch (e: Throwable) {
            val durationMs = currentTimeMs() - startMs
            val errorType = NetworkExceptionMapper.map(e)
            logger.e(TAG, "${request.method.value} $logUrl failed: $errorType", e)
            Result.Err(
                NetworkError.TransportError(
                    errorType = errorType,
                    requestId = requestId,
                    durationMs = durationMs,
                ),
            )
        }
    }

    override fun close() {
        httpClient.close()
    }

    /**
     * `bodyAsText()` with a byte ceiling.
     *
     * The plain `bodyAsText()` buffers whatever the peer sends into a single
     * `String` — every timeout in the client bounds *time*, none bounds *size*,
     * so a wedged gateway trickling an endless error page (or a compromised /
     * misconfigured host) can drive the process to OOM inside the 60 s budget.
     * This is the module's only body-read, so capping here caps every feature.
     *
     * Two paths, because a server may or may not tell us the size up front:
     *
     *  - **`Content-Length` present** — reject before a single body byte is
     *    buffered and drop the connection.
     *  - **Chunked / no `Content-Length`** — bound the read itself. Asking the
     *    channel for exactly one byte MORE than the ceiling is what makes "at
     *    the limit" and "over the limit" distinguishable without ever
     *    materializing an over-sized body.
     *
     * Throws [ResponseTooLargeException] on breach; `execute()`'s existing
     * `catch` turns it into `TransportError(OTHER_ERROR)` like any other
     * unusable payload.
     */
    private suspend fun readBodyCapped(response: HttpResponse): String {
        val declared = response.contentLength()
        if (declared != null && declared > maxResponseBytes) {
            response.bodyAsChannel().cancel()
            throw ResponseTooLargeException(declaredBytes = declared, maxBytes = maxResponseBytes)
        }

        val channel = response.bodyAsChannel()
        val source = channel.readRemaining(maxResponseBytes + 1)
        // `readRemaining(max)` — unlike the un-capped `readRemaining()` — does
        // NOT rethrow the channel's close cause, so a connection that broke
        // mid-body would otherwise read back as a short-but-valid payload.
        // Surface it as the transport failure it is (`bodyAsText()` threw here).
        channel.closedCause?.let { throw it }
        if (source.remaining > maxResponseBytes) {
            channel.cancel()
            throw ResponseTooLargeException(declaredBytes = null, maxBytes = maxResponseBytes)
        }
        // Honour the server's declared charset exactly as `bodyAsText()` does:
        // the response's own charset, UTF-8 only as the fallback.
        return source.readText(charset = response.charset() ?: Charsets.UTF_8)
    }

    // A cold-start gate (baseUrl or token hydration) never became ready within
    // the connect budget — surface a transport error rather than hang the caller
    // or fire an unauthenticated request.
    private fun coldGateError(requestId: String, startMs: Long): Result<SuccessResponse, NetworkError> =
        Result.Err(
            NetworkError.TransportError(
                errorType = AppErrorType.OTHER_ERROR,
                requestId = requestId,
                durationMs = currentTimeMs() - startMs,
            ),
        )

    companion object {
        /**
         * Client-wide response-body ceiling: **10 MiB**.
         *
         * Sized from what this app actually receives, not from a round number.
         * Every `:shared` endpoint returns a small JSON document — the largest
         * are `runners/me/app/current_state` (~2–8 KB typical, ~20–50 KB tail
         * once `widget_data` / `pre_action_nudges` / `sheet_warnings` are
         * populated), `seva/nearby` (~5–25 KB) and `runners/me` (~4–15 KB); the
         * rest are under 2 KB. No endpoint in the module paginates, but every
         * list is domain-bounded to a handful of rows (blocked customers, the
         * language set, home banners, the task catalogue). Remote **images**
         * never come through here — Coil owns a separate `HttpClient`
         * (`initSnabbitImageLoader`), so the only bytes this ceiling governs are
         * API JSON.
         *
         * 10 MiB therefore sits ~200× above the realistic worst response and
         * ~40× above even a pathological one, which is the point: it can only
         * ever fire on a runaway/hostile stream, never on a legitimate payload.
         * Tighten it (or make it per-request) only with fresh measurements.
         */
        const val DEFAULT_MAX_RESPONSE_BYTES: Long = 10L * 1024 * 1024
    }
}

/**
 * Materializes [parts] into a Ktor [MultiPartFormDataContent].
 *
 * Every file is read up-front via the suspending [readFileBytes] (which hops to
 * an IO dispatcher per platform) and only then handed to `formData` — the
 * builder itself is not suspend, so a read *inside* it would run on whatever
 * dispatcher the caller is on. Callers must therefore invoke this before
 * entering `httpClient.request { }`.
 */
private suspend fun buildMultipart(parts: List<FormPart>): MultiPartFormDataContent {
    val fileBytes: Map<String, ByteArray> = parts.filterIsInstance<FormPart.File>()
        .associate { it.filePath to readFileBytes(it.filePath) }

    return MultiPartFormDataContent(
        formData {
            parts.forEach { part ->
                when (part) {
                    is FormPart.Field -> append(part.name, part.value)
                    is FormPart.File -> append(
                        key = part.name,
                        value = fileBytes.getValue(part.filePath),
                        headers = Headers.build {
                            append(HttpHeaders.ContentType, part.mimeType)
                            append(
                                HttpHeaders.ContentDisposition,
                                "filename=\"${part.filename}\"",
                            )
                        },
                    )
                }
            }
        },
    )
}
