package com.snabbit.runner.shared.features.loan.data.repository

import com.snabbit.runner.shared.core.network.NetworkError
import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.core.result.RunnerActionError
import com.snabbit.runner.shared.features.loan.data.remote.LoanRemoteDataSource
import com.snabbit.runner.shared.features.loan.domain.model.LoanDetails
import com.snabbit.runner.shared.features.loan.domain.repository.LoanRepository

/**
 * Bridges [LoanRemoteDataSource] to [LoanRepository], collapsing [NetworkError]
 * into the generic [RunnerActionError] buckets the sheet needs (mirrors
 * `ProfileRepositoryImpl`).
 */
internal class LoanRepositoryImpl(
    private val remote: LoanRemoteDataSource,
) : LoanRepository {

    override suspend fun getLoanDetails(): Result<LoanDetails, RunnerActionError> =
        when (val r = remote.getLoanDetails()) {
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
