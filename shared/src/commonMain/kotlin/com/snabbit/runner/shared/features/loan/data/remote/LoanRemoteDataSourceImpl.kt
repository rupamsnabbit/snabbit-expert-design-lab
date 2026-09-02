package com.snabbit.runner.shared.features.loan.data.remote

import com.snabbit.runner.shared.core.network.AppErrorType
import com.snabbit.runner.shared.core.network.NetworkError
import com.snabbit.runner.shared.core.network.SnabbitHttpClient
import com.snabbit.runner.shared.core.network.SnabbitRequest
import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.features.loan.data.remote.dto.LoanDetailsDto
import com.snabbit.runner.shared.features.loan.domain.model.LoanDetails
import io.ktor.http.HttpMethod
import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.Json

/**
 * Production [LoanRemoteDataSource] — `GET api/v1/runners/me/loan_details` via the
 * shared [SnabbitHttpClient]. Auth + tracing headers come from the client's
 * interceptor chain. A 2xx body our schema can't parse collapses to a synthetic
 * `HttpError(OTHER_ERROR)` (mirrors `ProfileRemoteDataSourceImpl`).
 */
internal class LoanRemoteDataSourceImpl(
    private val httpClient: SnabbitHttpClient,
) : LoanRemoteDataSource {

    private val json = Json { ignoreUnknownKeys = true; isLenient = true }

    override suspend fun getLoanDetails(): Result<LoanDetails, NetworkError> {
        val result = httpClient.execute(
            SnabbitRequest(method = HttpMethod.Get, url = "/$LOAN_PATH"),
        )
        return when (result) {
            is Result.Ok -> try {
                Result.Ok(json.decodeFromString<LoanDetailsDto>(result.value.body).toDomain())
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
        const val LOAN_PATH = "api/v1/runners/me/loan_details"
    }
}
