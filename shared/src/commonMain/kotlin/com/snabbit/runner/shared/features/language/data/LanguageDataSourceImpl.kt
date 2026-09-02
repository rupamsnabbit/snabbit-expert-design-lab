package com.snabbit.runner.shared.features.language.data

import com.snabbit.runner.shared.core.CrashReporter
import com.snabbit.runner.shared.core.network.NetworkError
import com.snabbit.runner.shared.core.network.SnabbitHttpClient
import com.snabbit.runner.shared.core.network.SnabbitRequest
import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.features.language.domain.LanguageDataSource
import com.snabbit.runner.shared.features.language.domain.model.LanguageOption
import io.ktor.http.HttpMethod
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

/**
 * Production [LanguageDataSource] — talks to the runner language endpoints via
 * the KMP [SnabbitHttpClient]:
 *  - `GET   api/v1/runners/language_list`       — the list of languages.
 *  - `PATCH api/v1/runners/me/change_language`  — persist the chosen language.
 *
 * The list endpoint returns a top-level JSON array whose objects map 1:1 onto
 * [LanguageOption] (its `@SerialName`s already match the wire fields), so the
 * body deserializes straight into `List<LanguageOption>` — no DTO layer.
 *
 * Auth (Bearer) + tracing + `Content-Type: application/json` are applied by the
 * client's interceptor chain; this only builds the requests against the pushed
 * base URL. `suspend` + main-safe (the Ktor engine runs off the main thread).
 */
class LanguageDataSourceImpl(
    private val httpClient: SnabbitHttpClient,
    private val crashReporter: CrashReporter,
) : LanguageDataSource {

    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
    }

    override suspend fun getLanguages(): List<LanguageOption> {
        // The url is relative: baseUrl is pushed from Dart at cold start and
        // execute() resolves it itself (behind its cold-start gate), so callers
        // must not await the network config here.
        val result = httpClient.execute(
            SnabbitRequest(
                method = HttpMethod.Get,
                url = "/$LIST_PATH",
            ),
        )
        return when (result) {
            is Result.Ok -> json.decodeFromString<List<LanguageOption>>(result.value.body)
            is Result.Err -> throw reportAndWrap("getLanguages", result.error)
        }
    }

    override suspend fun setLanguage(code: String) {
        val result = httpClient.execute(
            SnabbitRequest(
                method = HttpMethod.Patch,
                url = "/$CHANGE_LANGUAGE_PATH",
                body = json.encodeToString(ChangeLanguageBody(languagePreference = code)),
            ),
        )
        if (result is Result.Err) throw reportAndWrap("setLanguage", result.error)
    }

    /**
     * Builds the typed exception for a failed language call and, for HTTP error
     * responses, reports it as a non-fatal first. HTTP errors (4xx/5xx) only
     * reach a local `logger.w` in [SnabbitHttpClientImpl.execute] otherwise, so
     * a save/load failure would be invisible in aggregate. Thrown transport
     * exceptions are skipped here — `NetworkExceptionPlugin` already reports
     * those, and reporting again would double-count. The [op] tag separates the
     * list fetch from the change-language write in the crash dashboard.
     */
    private fun reportAndWrap(op: String, error: NetworkError): LanguageNetworkException {
        val exception = LanguageNetworkException(error)
        if (error is NetworkError.HttpError) {
            crashReporter.report(
                exception,
                mapOf("op" to op, "status" to error.statusCode.toString()),
            )
        }
        return exception
    }

    private companion object {
        const val LIST_PATH = "api/v1/runners/language_list"
        const val CHANGE_LANGUAGE_PATH = "api/v1/runners/me/change_language"
    }
}

/** Request body for `PATCH api/v1/runners/me/change_language`. */
@Serializable
private data class ChangeLanguageBody(
    @SerialName("language_preference") val languagePreference: String,
)

/**
 * Raised when a language network call (list fetch or change) fails (HTTP or
 * transport error). [LanguageViewModel][com.snabbit.runner.shared.features.language.presentation.LanguageViewModel]
 * catches any [Throwable] and surfaces a generic message, so a typed wrapper is
 * enough — [error] is preserved for logging.
 */
class LanguageNetworkException(
    val error: NetworkError,
) : Exception("Language network call failed: $error")
