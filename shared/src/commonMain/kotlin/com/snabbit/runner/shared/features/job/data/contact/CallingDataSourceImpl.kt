package com.snabbit.runner.shared.features.job.data.contact

import com.snabbit.runner.shared.core.CrashReporter
import com.snabbit.runner.shared.core.network.NetworkError
import com.snabbit.runner.shared.core.network.SnabbitHttpClient
import com.snabbit.runner.shared.core.network.SnabbitRequest
import com.snabbit.runner.shared.core.result.Result
import io.ktor.http.HttpMethod

/**
 * Production [CallingDataSource] — posts the masked-call request via the KMP [SnabbitHttpClient]
 * (mirrors `LanguageDataSourceImpl`). The phone number is a path segment, matching the Flutter
 * `CallingService.initiateCall`. Auth + tracing come from the client's interceptor chain. An HTTP
 * error is reported as a non-fatal (transport errors are already reported by `NetworkExceptionPlugin`);
 * either way a failure returns `false` so the caller falls back to the dialer.
 */
class CallingDataSourceImpl(
    private val httpClient: SnabbitHttpClient,
    private val crashReporter: CrashReporter,
) : CallingDataSource {

    override suspend fun initiateCall(phoneNumber: String): Boolean {
        val result = httpClient.execute(
            SnabbitRequest(method = HttpMethod.Post, url = "/api/v1/runners/phone_call/$phoneNumber"),
        )
        return when (result) {
            is Result.Ok -> true
            is Result.Err -> {
                // Only report server-side failures (5xx). A 4xx here is an expected, benign path —
                // the caller falls back to the dialer — so reporting it is just Crashlytics noise.
                // Transport errors are already reported by NetworkExceptionPlugin.
                (result.error as? NetworkError.HttpError)
                    ?.takeIf { it.statusCode >= 500 }
                    ?.let { httpError ->
                        crashReporter.report(
                            CallingException(result.error),
                            mapOf("op" to "initiateCall", "status" to httpError.statusCode.toString()),
                        )
                    }
                false
            }
        }
    }
}

/** Wraps a failed masked-call request for crash reporting. */
class CallingException(val error: NetworkError) : Exception(
    // PII-safe message: don't interpolate the raw error `body` into the
    // crash-report message — the customer's number must not reach Crashlytics. Status/kind only.
    "Masked call request failed: ${(error as? NetworkError.HttpError)?.let { "HTTP ${it.statusCode}" } ?: "transport error"}",
)
