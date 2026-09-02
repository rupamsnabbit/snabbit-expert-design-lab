package com.snabbit.runner.shared.core.network

import com.snabbit.runner.shared.core.result.Result

/**
 * Single entry point for all KMP HTTP calls (§2, §7, §13).
 *
 * Interface-based so the production implementation
 * ([SnabbitHttpClientImpl]) can be substituted in tests via a Koin
 * module override — repositories depend on this contract, not on the
 * Ktor-backed concrete class. Translates the Ktor-side outcome into a
 * [Result] of [SuccessResponse] / [NetworkError] so callers never need
 * to reason about exceptions.
 */
interface SnabbitHttpClient {
    /**
     * Runs [request], resolving a relative [SnabbitRequest.url] against the
     * Dart-pushed base itself.
     *
     * There is deliberately **no** `awaitNetworkConfig()` on this contract.
     * The underlying gate (`NetworkConfigStore.awaitReady()`) is a
     * `first { … }` that suspends forever until a non-blank baseUrl arrives;
     * [execute] wraps its own call in `withTimeoutOrNull` so a never-arriving
     * config fails the request instead of hanging the caller. Exposing the
     * raw await let callers resolve the base *before* reaching [execute] and
     * so outside that guard — which is exactly how a disposition submit on a
     * cold process ended up wedged behind a non-dismissible spinner. Keeping
     * resolution inside the client makes that bypass unrepresentable rather
     * than merely discouraged.
     *
     * The response body is read under a size ceiling
     * ([SnabbitHttpClientImpl.DEFAULT_MAX_RESPONSE_BYTES]); a breach comes back
     * as `NetworkError.TransportError(AppErrorType.OTHER_ERROR)` rather than
     * being buffered. No `:shared` endpoint comes near it — see that constant.
     */
    suspend fun execute(request: SnabbitRequest): Result<SuccessResponse, NetworkError>

    fun close()
}
