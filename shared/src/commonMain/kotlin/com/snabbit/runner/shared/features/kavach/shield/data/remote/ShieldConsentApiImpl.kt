package com.snabbit.runner.shared.features.kavach.shield.data.remote

import com.snabbit.runner.shared.core.CrashReporter
import com.snabbit.runner.shared.core.network.NetworkError
import com.snabbit.runner.shared.core.network.SnabbitHttpClient
import com.snabbit.runner.shared.core.network.SnabbitRequest
import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.features.kavach.shared.data.ApiPreflight
import io.ktor.http.HttpMethod
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

/**
 * Production [ShieldConsentApi] over the KMP [SnabbitHttpClient]. Mirrors Flutter
 * `ShieldHttp.activateSnabbitShield`: `POST …/safety-shield/consent` with
 * `{consent:true, consent_version:"1.0"}`; success = 2xx (Flutter checks 200). The response
 * body is not parsed. Failures are reported (non-fatal) and return false.
 */
class ShieldConsentApiImpl(
    private val httpClient: SnabbitHttpClient,
    private val crashReporter: CrashReporter,
    private val preflight: ApiPreflight,
) : ShieldConsentApi {

    private val json = Json { encodeDefaults = true }   // always send both fields

    override suspend fun submitConsent(): Boolean {
        if (!preflight.allows("shield_consent")) return false
        val body = json.encodeToString(ConsentBody())
        return when (val r = httpClient.execute(SnabbitRequest(HttpMethod.Post, "/$CONSENT_PATH", body = body))) {
            is Result.Ok -> true
            is Result.Err -> { report(r.error); false }
        }
    }

    private fun report(error: NetworkError) {
        if (error is NetworkError.HttpError) {
            crashReporter.report(
                ShieldConsentException("consent activation failed: ${error.statusCode}"),
                mapOf("api" to "activate_consent", "status" to error.statusCode.toString()),
            )
        }
    }

    private companion object {
        const val CONSENT_PATH = "api/v1/runners/me/safety-shield/consent"
    }
}

@Serializable
private data class ConsentBody(
    val consent: Boolean = true,
    @SerialName("consent_version") val consentVersion: String = "1.0",
)
