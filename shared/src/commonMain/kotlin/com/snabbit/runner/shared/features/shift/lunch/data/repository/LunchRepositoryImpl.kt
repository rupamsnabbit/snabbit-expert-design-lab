package com.snabbit.runner.shared.features.shift.lunch.data.repository

import com.snabbit.runner.shared.core.network.NetworkError
import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.core.result.RunnerActionError
import com.snabbit.runner.shared.features.shift.lunch.data.remote.LunchRemoteDataSource
import com.snabbit.runner.shared.features.shift.lunch.domain.repository.LunchRepository

/**
 * Bridges the data-layer [LunchRemoteDataSource] to the domain [LunchRepository]
 * contract. The break endpoints return no structured body, so every action uses
 * the same generic status-code mapping as `ShiftRepositoryImpl.toLogoutError` —
 * the UI only needs a snackbar string + retry policy.
 */
internal class LunchRepositoryImpl(
    private val remote: LunchRemoteDataSource,
) : LunchRepository {

    override suspend fun acceptLunch(): Result<Unit, RunnerActionError> =
        remote.acceptLunch().toActionResult()

    override suspend fun denyLunch(): Result<Unit, RunnerActionError> =
        remote.denyLunch().toActionResult()

    override suspend fun endBreak(lat: Double?, lng: Double?): Result<Unit, RunnerActionError> =
        remote.endBreak(lat = lat, lng = lng).toActionResult()

    private fun Result<Unit, NetworkError>.toActionResult(): Result<Unit, RunnerActionError> =
        when (this) {
            is Result.Ok -> Result.Ok(Unit)
            is Result.Err -> Result.Err(error.toActionError())
        }

    private fun NetworkError.toActionError(): RunnerActionError = when (this) {
        is NetworkError.TransportError -> RunnerActionError.NoConnection
        is NetworkError.HttpError -> when (statusCode) {
            401, 403 -> RunnerActionError.Unauthorized
            in 500..599 -> RunnerActionError.Server
            else -> RunnerActionError.Unknown(statusCode)
        }
    }
}
