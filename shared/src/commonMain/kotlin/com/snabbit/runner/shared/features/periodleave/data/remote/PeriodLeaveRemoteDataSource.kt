package com.snabbit.runner.shared.features.periodleave.data.remote

import com.snabbit.runner.shared.core.Logger
import com.snabbit.runner.shared.core.defaultLogger
import com.snabbit.runner.shared.core.network.AppErrorType
import com.snabbit.runner.shared.core.network.NetworkError
import com.snabbit.runner.shared.core.network.SnabbitHttpClient
import com.snabbit.runner.shared.core.network.SnabbitRequest
import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.features.periodleave.data.remote.dto.PeriodLeaveAvailabilityDto
import com.snabbit.runner.shared.features.periodleave.domain.model.PeriodLeaveAvailability
import io.ktor.http.HttpMethod
import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.Json

/**
 * Thin remote contract for the runner period-leave endpoints. Returns the
 * core [Result] type so failures are values, not exceptions — the repository
 * collapses the network failure into the domain error sealed type.
 */
internal interface PeriodLeaveRemoteDataSource {
    /** `GET api/v1/runners/me/period_leave/availability`. */
    suspend fun getAvailability(): Result<PeriodLeaveAvailability, NetworkError>
}

/**
 * Production [PeriodLeaveRemoteDataSource] — talks to the period-leave
 * availability endpoint via the shared [SnabbitHttpClient]:
 *  - `GET api/v1/runners/me/period_leave/availability`
 *
 * Auth + tracing headers are applied by the client's interceptor chain. A
 * malformed body collapses to a synthetic 200 HttpError so the repository's
 * status-bucket mapping can route it as "Unknown" without bypassing the
 * domain-error sealed type.
 */
internal class PeriodLeaveRemoteDataSourceImpl(
    private val httpClient: SnabbitHttpClient,
    // Defaults to the platform logger (== Koin's `single<Logger>`); DI/tests
    // need not pass it. Used to leave a breadcrumb on a malformed 2xx body.
    private val logger: Logger = defaultLogger(),
) : PeriodLeaveRemoteDataSource {

    private val json = Json { ignoreUnknownKeys = true; isLenient = true }

    override suspend fun getAvailability(): Result<PeriodLeaveAvailability, NetworkError> {
        val result = httpClient.execute(
            SnabbitRequest(method = HttpMethod.Get, url = "/$AVAILABILITY_PATH"),
        )
        return when (result) {
            is Result.Ok -> try {
                Result.Ok(json.decodeFromString<PeriodLeaveAvailabilityDto>(result.value.body).toDomain())
            } catch (e: SerializationException) {
                // Server returned 2xx with a body our schema couldn't parse — map to a
                // synthetic HttpError (OTHER_ERROR) so the repo's status-bucket mapping
                // routes it as Unknown instead of crashing.
                logger.w(
                    TAG,
                    "period_leave/availability: unparseable 2xx body " +
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
        const val TAG = "PeriodLeaveRemoteDataSource"
        const val AVAILABILITY_PATH = "api/v1/runners/me/period_leave/availability"
    }
}
