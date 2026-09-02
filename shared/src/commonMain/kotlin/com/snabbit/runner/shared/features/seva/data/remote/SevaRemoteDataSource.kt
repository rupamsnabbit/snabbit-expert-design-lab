package com.snabbit.runner.shared.features.seva.data.remote

import com.snabbit.runner.shared.core.Logger
import com.snabbit.runner.shared.core.defaultLogger
import com.snabbit.runner.shared.core.network.AppErrorType
import com.snabbit.runner.shared.core.network.NetworkError
import com.snabbit.runner.shared.core.network.SnabbitHttpClient
import com.snabbit.runner.shared.core.network.SnabbitRequest
import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.features.seva.data.remote.dto.SevaNearbyDto
import com.snabbit.runner.shared.features.seva.domain.model.SevaPoint
import io.ktor.http.HttpMethod
import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.Json

/**
 * Thin remote contract for `GET /seva/nearby`. Returns the core [Result] so a
 * network failure is a value the repository collapses into a domain error —
 * never an exception. A malformed 200 body maps to a synthetic
 * [NetworkError.HttpError] so the caller treats it like any other server fault.
 */
internal interface SevaRemoteDataSource {
    /** `GET seva/nearby?lat=&lng=&radius=&type=` — nearby washrooms + resting
     *  places flattened into one list. [radius] is clamped to the backend's
     *  1..1000 m range by the implementation. */
    suspend fun nearby(
        lat: Double,
        lng: Double,
        radius: Int,
        type: String,
    ): Result<List<SevaPoint>, NetworkError>
}

/**
 * Production [SevaRemoteDataSource] — `GET seva/nearby` via the shared
 * [SnabbitHttpClient]. Auth + tracing headers are added by the client's
 * interceptor chain. Mirrors [com.snabbit.runner.shared.features.shift.core.data.remote.ShiftRemoteDataSourceImpl]'s
 * decode-or-synthetic-HttpError shape so a malformed body never crashes.
 */
internal class SevaRemoteDataSourceImpl(
    private val httpClient: SnabbitHttpClient,
    // Defaults to the platform logger (== Koin's `single<Logger>`); DI/tests
    // need not pass it. Used to leave a breadcrumb on a malformed 2xx body.
    private val logger: Logger = defaultLogger(),
) : SevaRemoteDataSource {

    private val json = Json { ignoreUnknownKeys = true; isLenient = true }

    override suspend fun nearby(
        lat: Double,
        lng: Double,
        radius: Int,
        type: String,
    ): Result<List<SevaPoint>, NetworkError> {
        val result = httpClient.execute(
            SnabbitRequest(
                method = HttpMethod.Get,
                url = "/$NEARBY_PATH",
                query = mapOf(
                    "lat" to lat.toString(),
                    "lng" to lng.toString(),
                    // Backend rejects radius > 1000 with a 422 — clamp so a
                    // caller can't turn a wide search into a hard failure.
                    "radius" to radius.coerceIn(MIN_RADIUS_M, MAX_RADIUS_M).toString(),
                    "type" to type,
                ),
            ),
        )
        return when (result) {
            is Result.Ok -> try {
                Result.Ok(json.decodeFromString<SevaNearbyDto>(result.value.body).toDomain())
            } catch (e: SerializationException) {
                logger.w(
                    TAG,
                    "seva/nearby: unparseable 2xx body " +
                        "(requestId=${result.value.requestId})",
                    e,
                )
                Result.Err(
                    NetworkError.HttpError(
                        statusCode = result.value.statusCode,
                        body = result.value.body,
                        errorType = AppErrorType.OTHER_ERROR,
                        requestId = result.value.requestId,
                        durationMs = result.value.durationMs,
                    ),
                )
            }
            is Result.Err -> Result.Err(result.error)
        }
    }

    private companion object {
        const val TAG = "SevaRemoteDataSource"
        // Backend mounts the api sub-app at /api/v1 (main.py: app.mount("/api/v1", ...)),
        // seva_router under prefix "/seva" → GET /api/v1/seva/nearby. Without the api/v1
        // prefix (as every other endpoint carries) the request 404s.
        const val NEARBY_PATH = "api/v1/seva/nearby"
        const val MIN_RADIUS_M = 1
        const val MAX_RADIUS_M = 1000
    }
}
