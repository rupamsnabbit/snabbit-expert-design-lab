package com.snabbit.runner.shared.features.profile.data.remote

import com.snabbit.runner.shared.core.network.AppErrorType
import com.snabbit.runner.shared.core.network.NetworkError
import com.snabbit.runner.shared.core.network.SnabbitHttpClient
import com.snabbit.runner.shared.core.network.SnabbitRequest
import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.features.profile.data.remote.dto.RunnerProfileDto
import com.snabbit.runner.shared.features.profile.domain.model.RunnerProfile
import io.ktor.http.HttpMethod
import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.Json

/**
 * Production [ProfileRemoteDataSource] — fetches the runner profile via the
 * shared [SnabbitHttpClient]:
 *  - `GET api/v1/runners/me` (the `app_config` object is embedded in the body).
 *
 * Auth (Bearer) + tracing headers are applied by the client's interceptor chain;
 * this only builds the request against the pushed base URL. A 2xx body our schema
 * can't parse collapses to a synthetic `HttpError(OTHER_ERROR)` so the repository's
 * status-bucket mapping routes it as `Unknown` rather than crashing (mirrors
 * `PeriodLeaveRemoteDataSourceImpl`).
 */
internal class ProfileRemoteDataSourceImpl(
    private val httpClient: SnabbitHttpClient,
) : ProfileRemoteDataSource {

    private val json = Json { ignoreUnknownKeys = true; isLenient = true }

    override suspend fun getProfile(): Result<RunnerProfile, NetworkError> {
        val result = httpClient.execute(
            SnabbitRequest(method = HttpMethod.Get, url = "/$ME_PATH"),
        )
        return when (result) {
            is Result.Ok -> try {
                Result.Ok(json.decodeFromString<RunnerProfileDto>(result.value.body).toDomain())
            } catch (_: SerializationException) {
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
        const val ME_PATH = "api/v1/runners/me"
    }
}
