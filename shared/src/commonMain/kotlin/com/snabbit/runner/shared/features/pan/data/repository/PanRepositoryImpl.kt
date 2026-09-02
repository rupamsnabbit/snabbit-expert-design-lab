package com.snabbit.runner.shared.features.pan.data.repository

import com.snabbit.runner.shared.core.network.NetworkError
import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.features.pan.data.remote.PanRemoteDataSource
import com.snabbit.runner.shared.features.pan.domain.repository.PanRepository
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive

/**
 * Bridges [PanRemoteDataSource] to [PanRepository], deciding PAN-update success and
 * turning a rejection into the user-facing message the sheet shows.
 *
 * Mirrors `upload_pan_modal_sheet_v2.dart` exactly: a `2xx` is **only** a success
 * when its body has no non-empty `errors[]` — the backend rejects an invalid PAN
 * with `200` + `errors[]`. The message is `errors[0].message` (Dart's
 * `errorData['message']`), falling back to a top-level `message`, then a safe default.
 */
internal class PanRepositoryImpl(
    private val remote: PanRemoteDataSource,
) : PanRepository {

    private val json = Json { ignoreUnknownKeys = true; isLenient = true }

    override suspend fun updatePan(panNumber: String): Result<Unit, String> =
        when (val r = remote.updatePan(panNumber)) {
            // 2xx: a non-empty `errors[]` in the body means the PAN was rejected.
            is Result.Ok -> if (hasErrors(r.value)) Result.Err(serverMessage(r.value)) else Result.Ok(Unit)
            is Result.Err -> Result.Err(r.error.toMessage())
        }

    private fun NetworkError.toMessage(): String = when (this) {
        is NetworkError.TransportError -> DEFAULT_ERROR
        is NetworkError.HttpError -> serverMessage(body)
    }

    /** True when [body] carries a non-empty `errors` array (Dart's failure check). */
    private fun hasErrors(body: String): Boolean = runCatching {
        val obj = json.parseToJsonElement(body) as? JsonObject
        (obj?.get("errors") as? JsonArray)?.isNotEmpty() == true
    }.getOrDefault(false)

    /** `errors[0].message` → top-level `message` → [DEFAULT_ERROR]. */
    private fun serverMessage(body: String): String = runCatching {
        val obj = json.parseToJsonElement(body) as? JsonObject
        val fromErrors = (obj?.get("errors") as? JsonArray)?.firstOrNull()
            ?.let { it as? JsonObject }?.get("message")
            ?.let { it as? JsonPrimitive }?.takeIf { it.isString }?.content?.takeIf { it.isNotBlank() }
        val fromTop = (obj?.get("message") as? JsonPrimitive)
            ?.takeIf { it.isString }?.content?.takeIf { it.isNotBlank() }
        fromErrors ?: fromTop
    }.getOrNull() ?: DEFAULT_ERROR

    private companion object {
        const val DEFAULT_ERROR = "PAN verification failed. Please try again."
    }
}
