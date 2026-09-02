package com.snabbit.runner.shared.features.shift.attendance.data.repository

import com.snabbit.runner.shared.features.shift.attendance.data.remote.AttendanceRemoteDataSource
import com.snabbit.runner.shared.features.shift.attendance.domain.repository.AttendanceRepository
import com.snabbit.runner.shared.core.network.NetworkError
import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.core.result.RunnerActionError
import com.snabbit.runner.shared.features.gamification.domain.model.PostActionOutcome

/**
 * Bridges the data-layer [AttendanceRemoteDataSource] to the domain
 * [AttendanceRepository] contract by collapsing [NetworkError] cases into
 * [RunnerActionError] so the domain + presentation layers never see HTTP
 * types. Status-code buckets are deliberately coarse — UI only needs them to
 * pick a snackbar string + retry policy.
 */
internal class AttendanceRepositoryImpl(
    private val remote: AttendanceRemoteDataSource,
) : AttendanceRepository {

    override suspend fun markProvisional(present: Boolean): Result<PostActionOutcome?, RunnerActionError> =
        remote.markProvisional(present).mapError()

    override suspend fun changeAttendance(
        present: Boolean,
        shiftDateIst: String,
    ): Result<PostActionOutcome?, RunnerActionError> =
        remote.changeAttendance(present, shiftDateIst).mapError()

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
