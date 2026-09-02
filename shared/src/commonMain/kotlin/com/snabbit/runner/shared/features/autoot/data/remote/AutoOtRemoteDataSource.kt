package com.snabbit.runner.shared.features.autoot.data.remote

import com.snabbit.runner.shared.core.network.NetworkError
import com.snabbit.runner.shared.core.network.SnabbitHttpClient
import com.snabbit.runner.shared.core.network.SnabbitRequest
import com.snabbit.runner.shared.core.network.SuccessResponse
import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.features.autoot.data.remote.dto.AutoOtDto
import com.snabbit.runner.shared.features.autoot.domain.model.AutoOtDenyReason
import com.snabbit.runner.shared.features.autoot.domain.model.AutoOtDetails
import io.ktor.http.HttpMethod
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

/**
 * Thin remote contract for the three Auto-OT endpoints (Flutter `AutoOtHttp`).
 * Returns the core [Result] so failures are values, not exceptions — the
 * repository layer collapses [NetworkError] into the domain error type.
 */
internal interface AutoOtRemoteDataSource {
    suspend fun accept(requestId: Int): Result<Unit, NetworkError>
    suspend fun reject(requestId: Int, reason: AutoOtDenyReason): Result<Unit, NetworkError>
    suspend fun requestStartOt(): Result<AutoOtDetails?, NetworkError>
}

/**
 * Production [AutoOtRemoteDataSource] over the shared [SnabbitHttpClient] (auth +
 * tracing via the interceptor chain; base URL pushed from Dart). Bodies mirror
 * Flutter: accept + start-ot POST `{}`, reject POSTs `{"rejection_reason"}`.
 */
internal class AutoOtRemoteDataSourceImpl(
    private val httpClient: SnabbitHttpClient,
) : AutoOtRemoteDataSource {

    private val json = Json { ignoreUnknownKeys = true; isLenient = true }

    override suspend fun accept(requestId: Int): Result<Unit, NetworkError> =
        when (val r = post("api/v1/auto-ot/requests/$requestId/accept", EMPTY_BODY)) {
            is Result.Ok -> Result.Ok(Unit)
            is Result.Err -> r
        }

    override suspend fun reject(requestId: Int, reason: AutoOtDenyReason): Result<Unit, NetworkError> {
        val body = json.encodeToString(RejectBody(reason.apiValue))
        return when (val r = post("api/v1/auto-ot/requests/$requestId/reject", body)) {
            is Result.Ok -> Result.Ok(Unit)
            is Result.Err -> r
        }
    }

    override suspend fun requestStartOt(): Result<AutoOtDetails?, NetworkError> =
        when (val r = post("api/v1/auto-ot/start-ot/request", EMPTY_BODY)) {
            is Result.Ok -> Result.Ok(r.value.toOfferOrNull())
            is Result.Err -> r
        }

    /** Decode the `auto_ot`-shaped body; a missing request id (empty `{}`) = no offer. */
    private fun SuccessResponse.toOfferOrNull(): AutoOtDetails? =
        runCatching { json.decodeFromString<AutoOtDto>(body).toDomain() }
            .getOrNull()
            ?.takeIf { it.isComplete }

    private suspend fun post(path: String, body: String): Result<SuccessResponse, NetworkError> {
        return httpClient.execute(SnabbitRequest(method = HttpMethod.Post, url = "/$path", body = body))
    }

    private companion object {
        const val EMPTY_BODY = "{}"
    }
}

@Serializable
private data class RejectBody(@SerialName("rejection_reason") val rejectionReason: String)
