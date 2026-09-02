package com.snabbit.runner.shared.core.network.interceptors

import com.snabbit.runner.shared.core.network.NetworkConfigStore
import com.snabbit.runner.shared.core.network.RequestIdGenerator
import io.ktor.client.request.HttpRequestBuilder
import io.ktor.http.ContentType
import io.ktor.http.contentType

/**
 * Injects metadata/tracing headers (§3.2):
 *  - `x-version-code` from [NetworkConfigStore.snapshot] (set when Dart
 *    pushes config).
 *  - `X-Request-ID` generated per-call by [RequestIdGenerator].
 *  - `Content-Type: application/json` for non-multipart calls. Multipart
 *    requests skip this header so Ktor's `submitFormWithBinaryData` can
 *    set the correct `multipart/form-data; boundary=…`.
 */
class RequestInterceptor(
    private val networkConfigStore: NetworkConfigStore,
    private val requestIdGenerator: RequestIdGenerator,
) {

    /** Applies the headers and returns the generated request ID so the
     * caller can echo it into log/response metadata. */
    fun applyTo(
        builder: HttpRequestBuilder,
        method: String,
        baseUrl: String,
        isMultipart: Boolean,
    ): String {
        networkConfigStore.snapshot()?.versionCode?.let { vc ->
            builder.headers.append("x-version-code", vc)
        }
        val requestId = requestIdGenerator.generate(method, baseUrl)
        builder.headers.append("X-Request-ID", requestId)

        if (!isMultipart) {
            builder.contentType(ContentType.Application.Json)
        }
        return requestId
    }
}
