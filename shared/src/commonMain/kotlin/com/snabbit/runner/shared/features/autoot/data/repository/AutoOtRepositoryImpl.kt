package com.snabbit.runner.shared.features.autoot.data.repository

import com.snabbit.runner.shared.core.network.NetworkError
import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.core.result.RunnerActionError
import com.snabbit.runner.shared.features.autoot.data.remote.AutoOtRemoteDataSource
import com.snabbit.runner.shared.features.autoot.domain.model.AutoOtDenyReason
import com.snabbit.runner.shared.features.autoot.domain.model.AutoOtDetails
import com.snabbit.runner.shared.features.autoot.domain.repository.AutoOtRepository

/**
 * Bridges [AutoOtRemoteDataSource] to the domain [AutoOtRepository] by collapsing
 * [NetworkError] into [RunnerActionError] — identical status-code buckets to
 * `AttendanceRepositoryImpl`. Reject is best-effort (callers ignore its error).
 */
internal class AutoOtRepositoryImpl(
    private val remote: AutoOtRemoteDataSource,
) : AutoOtRepository {

    override suspend fun accept(requestId: Int): Result<Unit, RunnerActionError> =
        remote.accept(requestId).mapError()

    override suspend fun reject(requestId: Int, reason: AutoOtDenyReason): Result<Unit, RunnerActionError> =
        remote.reject(requestId, reason).mapError()

    override suspend fun requestStartOt(): Result<AutoOtDetails?, RunnerActionError> =
        remote.requestStartOt().mapError()

    private fun <T> Result<T, NetworkError>.mapError(): Result<T, RunnerActionError> =
        when (this) {
            is Result.Ok -> Result.Ok(value)
            is Result.Err -> Result.Err(error.toDomain())
        }

    private fun NetworkError.toDomain(): RunnerActionError = when (this) {
        is NetworkError.TransportError -> RunnerActionError.NoConnection
        is NetworkError.HttpError -> when (statusCode) {
            401, 403 -> RunnerActionError.Unauthorized
            in 500..599 -> RunnerActionError.Server
            else -> RunnerActionError.Unknown(statusCode)
        }
    }
}
