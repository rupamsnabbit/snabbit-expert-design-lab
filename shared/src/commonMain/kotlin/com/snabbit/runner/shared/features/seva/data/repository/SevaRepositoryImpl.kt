package com.snabbit.runner.shared.features.seva.data.repository

import com.snabbit.runner.shared.core.network.NetworkError
import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.core.result.RunnerActionError
import com.snabbit.runner.shared.features.seva.data.remote.SevaRemoteDataSource
import com.snabbit.runner.shared.features.seva.domain.model.SevaPoint
import com.snabbit.runner.shared.features.seva.domain.repository.SevaRepository

/**
 * Bridges [SevaRemoteDataSource] to the domain [SevaRepository], mapping
 * [NetworkError] into the shared [RunnerActionError] status buckets — the same
 * collapse `ShiftRepositoryImpl` does for its empty-body actions.
 */
internal class SevaRepositoryImpl(
    private val remote: SevaRemoteDataSource,
) : SevaRepository {

    override suspend fun nearby(
        lat: Double,
        lng: Double,
        radius: Int,
        type: String,
    ): Result<List<SevaPoint>, RunnerActionError> =
        when (val r = remote.nearby(lat, lng, radius, type)) {
            is Result.Ok -> Result.Ok(r.value)
            is Result.Err -> Result.Err(r.error.toActionError())
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
