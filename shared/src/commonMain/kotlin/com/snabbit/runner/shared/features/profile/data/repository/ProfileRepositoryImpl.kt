package com.snabbit.runner.shared.features.profile.data.repository

import com.snabbit.runner.shared.core.network.NetworkError
import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.core.result.RunnerActionError
import com.snabbit.runner.shared.features.profile.data.remote.ProfileRemoteDataSource
import com.snabbit.runner.shared.features.profile.domain.model.RunnerProfile
import com.snabbit.runner.shared.features.profile.domain.repository.ProfileRepository

/**
 * Bridges the data-layer [ProfileRemoteDataSource] to the domain
 * [ProfileRepository] by collapsing [NetworkError] into the generic
 * [RunnerActionError] buckets the UI needs (message + retry). Mirrors
 * `PeriodLeaveRepositoryImpl`.
 */
internal class ProfileRepositoryImpl(
    private val remote: ProfileRemoteDataSource,
) : ProfileRepository {

    override suspend fun getProfile(): Result<RunnerProfile, RunnerActionError> =
        when (val r = remote.getProfile()) {
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
