package com.snabbit.runner.shared.features.kavach.sos.data.remote

import com.snabbit.runner.shared.core.CrashReporter
import com.snabbit.runner.shared.core.network.NetworkError
import com.snabbit.runner.shared.core.network.SnabbitHttpClient
import com.snabbit.runner.shared.core.network.SnabbitRequest
import com.snabbit.runner.shared.core.network.SuccessResponse
import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.features.kavach.shared.data.ApiPreflight
import io.ktor.http.HttpMethod
import io.ktor.http.encodeURLPathPart
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

/**
 * Production [SosApi] over the KMP [SnabbitHttpClient] (auth/tracing via the interceptor
 * chain). Best-effort like the Flutter SOS flow: HTTP/transport failures are reported
 * (non-fatal) and return null/false — the caller decides. Base URL is pushed from Dart.
 */
class SosApiImpl(
    private val httpClient: SnabbitHttpClient,
    private val crashReporter: CrashReporter,
    private val preflight: ApiPreflight,
) : SosApi {

    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
        encodeDefaults = false   // omit null job_id / sos_id (matches the Flutter conditional body)
    }

    override suspend fun initiate(source: String, triggerType: String, jobId: Int?): Int? {
        val body = json.encodeToString(InitiateBody(source, triggerType, jobId))
        val resp = post(INITIATE_PATH, body, op = "initiate") ?: return null
        return runCatching { json.decodeFromString<InitiateResponse>(resp.body).sosId }.getOrNull()
    }

    override suspend fun resolve(sosId: Int?, action: SosUserAction): ResolveOutcome {
        val body = json.encodeToString(ResolveBody(sosId, action.apiValue))
        // post() returns null on a pre-flight skip or any HTTP/transport failure — not delivered.
        val resp = post(RESOLVE_PATH, body, op = "resolve") ?: return ResolveOutcome(delivered = false)
        // 2xx = the backend has the action. A missing/garbled ph_no doesn't undo that.
        val phone = runCatching { json.decodeFromString<ResolveResponse>(resp.body).phNo }.getOrNull()
        return ResolveOutcome(delivered = true, phoneNumber = phone)
    }

    override suspend fun active(): ActiveSosState? {
        // Logged out → nothing to reconcile. Null is the same "no change" signal reconcile() already
        // treats as a failure, so a skipped check can never clear a live SOS.
        if (!preflight.allows("sos_active")) return null
        return when (val r = httpClient.execute(SnabbitRequest(HttpMethod.Get, "/$ACTIVE_PATH"))) {
            is Result.Ok -> runCatching {
                val dto = json.decodeFromString<ActiveResponse>(r.value.body)
                // No has_active_sos → we cannot tell; return null (no change) rather than guess "none".
                dto.hasActiveSos?.let { ActiveSosState(it, dto.sos?.status, dto.sos?.sosId, dto.sos?.phNo) }
            }.getOrNull()
            is Result.Err -> { report("active", r.error); null }
        }
    }

    override suspend fun callSosTeam(phoneNumber: String): Boolean {
        if (phoneNumber.isBlank()) return false
        if (!preflight.allows("sos_call_team")) return false
        // Encode the phone into the path — a '+' country code or a space would otherwise malform the URL
        // and fail the call (dead "Call SoS Team" during a live SOS). Don't strip to digits — the backend
        // may need the '+'.
        return when (val r = httpClient.execute(SnabbitRequest(HttpMethod.Post, "/$PHONE_CALL_PATH${phoneNumber.encodeURLPathPart()}"))) {
            is Result.Ok -> true
            is Result.Err -> { report("callSosTeam", r.error); false }
        }
    }

    // Covers initiate + resolve. Both already treat null as "call failed", which the callers surface.
    private suspend fun post(path: String, body: String, op: String): SuccessResponse? {
        if (!preflight.allows("sos_$op")) return null
        return when (val r = httpClient.execute(SnabbitRequest(HttpMethod.Post, "/$path", body = body))) {
            is Result.Ok -> r.value
            is Result.Err -> { report(op, r.error); null }
        }
    }

    // Report ALL NetworkError variants, not just HTTP — the class contract says transport failures are
    // reported, and an offline active()/resolve() on the SOS path was otherwise fully silent. Non-fatal.
    private fun report(op: String, error: NetworkError) {
        val extras = if (error is NetworkError.HttpError) {
            mapOf("op" to op, "status" to error.statusCode.toString())
        } else {
            mapOf("op" to op, "type" to (error::class.simpleName ?: "network_error"))
        }
        crashReporter.report(SosNetworkException(error), extras)
    }

    private companion object {
        const val INITIATE_PATH = "api/v1/runners/me/sos/initiate"
        const val RESOLVE_PATH = "api/v1/runners/me/sos"
        const val ACTIVE_PATH = "api/v1/runners/me/sos/active"
        const val PHONE_CALL_PATH = "api/v1/runners/phone_call/"
    }
}

@Serializable
private data class InitiateBody(
    val source: String,
    @SerialName("trigger_type") val triggerType: String,
    @SerialName("job_id") val jobId: Int? = null,
)

@Serializable
private data class ResolveBody(
    @SerialName("sos_id") val sosId: Int? = null,
    @SerialName("user_action") val userAction: String,
)

@Serializable
private data class InitiateResponse(@SerialName("sos_id") val sosId: Int? = null)

@Serializable
private data class ResolveResponse(@SerialName("ph_no") val phNo: String? = null)

@Serializable
private data class ActiveResponse(
    // Nullable, NOT `= false`. With ignoreUnknownKeys + isLenient, any well-formed JSON of the wrong
    // shape (envelope change, maintenance stub, proxy error page) decodes successfully — and a `false`
    // default would read as "no active SOS", which makes reconcile() cancel the alert timer and wipe a
    // live SOS. Absent = unknown, and [SosApi.active] maps that to null so reconcile takes its
    // no-change path instead.
    @SerialName("has_active_sos") val hasActiveSos: Boolean? = null,
    val sos: ActiveSosDto? = null,
)

@Serializable
private data class ActiveSosDto(
    val status: String? = null,
    @SerialName("sos_id") val sosId: Int? = null,
    @SerialName("ph_no") val phNo: String? = null,
)

/** Typed wrapper for a failed SOS call — [error] preserved for logging. */
class SosNetworkException(val error: NetworkError) : Exception("SOS network call failed: $error")
