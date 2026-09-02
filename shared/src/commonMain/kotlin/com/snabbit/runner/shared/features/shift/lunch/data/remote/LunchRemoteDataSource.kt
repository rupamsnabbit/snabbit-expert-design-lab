package com.snabbit.runner.shared.features.shift.lunch.data.remote

import com.snabbit.runner.shared.core.network.NetworkError
import com.snabbit.runner.shared.core.network.SnabbitHttpClient
import com.snabbit.runner.shared.core.network.SnabbitRequest
import com.snabbit.runner.shared.core.result.Result
import io.ktor.http.HttpMethod
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonObject

/**
 * Thin remote contract for the in-shift break endpoints. Returns the core
 * [Result] so failures are values; the repository collapses [NetworkError] into
 * the domain [com.snabbit.runner.shared.core.result.RunnerActionError]. Response
 * bodies are discarded — the client re-polls `current_state` to pick up the next
 * widget envelope after each action.
 */
internal interface LunchRemoteDataSource {
    /** `POST api/v1/runners/me/lunch/accept` — empty body. */
    suspend fun acceptLunch(): Result<Unit, NetworkError>

    /** `POST api/v1/runners/me/lunch/deny` — empty body. */
    suspend fun denyLunch(): Result<Unit, NetworkError>

    /**
     * `POST api/v1/runners/me/break/end` — body carries `{"location":{lat,lng}}`
     * when coords are present, else `{}`.
     */
    suspend fun endBreak(lat: Double?, lng: Double?): Result<Unit, NetworkError>
}

/**
 * Production [LunchRemoteDataSource] — talks to the break endpoints via the
 * shared [SnabbitHttpClient]. Auth + tracing + `Content-Type` are applied by the
 * client's interceptor chain; bodies are ignored on success (the next
 * `current_state` poll carries the resulting widget).
 *
 * Location body is built with `buildJsonObject` rather than string concatenation
 * so doubles are encoded safely (no locale / precision surprises).
 */
internal class LunchRemoteDataSourceImpl(
    private val httpClient: SnabbitHttpClient,
) : LunchRemoteDataSource {

    override suspend fun acceptLunch(): Result<Unit, NetworkError> = post(ACCEPT_PATH, EMPTY_BODY)

    override suspend fun denyLunch(): Result<Unit, NetworkError> = post(DENY_PATH, EMPTY_BODY)

    override suspend fun endBreak(lat: Double?, lng: Double?): Result<Unit, NetworkError> =
        post(BREAK_END_PATH, locationBody(lat, lng))

    private suspend fun post(path: String, body: String): Result<Unit, NetworkError> {
        val result = httpClient.execute(
            SnabbitRequest(method = HttpMethod.Post, url = "/$path", body = body),
        )
        return when (result) {
            is Result.Ok -> Result.Ok(Unit)
            is Result.Err -> Result.Err(result.error)
        }
    }

    /** `{"location":{"lat":..,"lng":..}}` when both coords present, else `{}`. */
    private fun locationBody(lat: Double?, lng: Double?): String {
        if (lat == null || lng == null) return EMPTY_BODY
        return buildJsonObject {
            putJsonObject("location") {
                put("lat", lat)
                put("lng", lng)
            }
        }.toString()
    }

    private companion object {
        const val EMPTY_BODY = "{}"
        const val ACCEPT_PATH = "api/v1/runners/me/lunch/accept"
        const val DENY_PATH = "api/v1/runners/me/lunch/deny"
        const val BREAK_END_PATH = "api/v1/runners/me/break/end"
    }
}
