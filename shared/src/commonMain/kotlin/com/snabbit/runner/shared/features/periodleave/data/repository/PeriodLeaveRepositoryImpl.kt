package com.snabbit.runner.shared.features.periodleave.data.repository

import com.snabbit.runner.shared.core.network.NetworkError
import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.core.result.RunnerActionError
import com.snabbit.runner.shared.features.periodleave.data.remote.PeriodLeaveRemoteDataSource
import com.snabbit.runner.shared.features.periodleave.domain.model.PeriodLeaveAvailability
import com.snabbit.runner.shared.features.periodleave.domain.repository.PeriodLeaveRepository

/**
 * Bridges the data-layer [PeriodLeaveRemoteDataSource] to the domain
 * [PeriodLeaveRepository] contract by collapsing [NetworkError] into the
 * generic [RunnerActionError] buckets the UI needs (snackbar + retry).
 */
internal class PeriodLeaveRepositoryImpl(
    private val remote: PeriodLeaveRemoteDataSource,
) : PeriodLeaveRepository {

    override suspend fun getAvailability(): Result<PeriodLeaveAvailability, RunnerActionError> =
        when (val r = remote.getAvailability()) {
            is Result.Ok -> Result.Ok(r.value)
            is Result.Err -> Result.Err(r.error.toDomain())
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
