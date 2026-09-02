package com.snabbit.runner.shared.features.profile.data.remote

import com.snabbit.runner.shared.core.network.NetworkError
import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.features.profile.domain.model.RunnerProfile

/**
 * Data-layer seam for the runner profile fetch (`GET api/v1/runners/me`).
 * Returns the network-shaped [Result] ([NetworkError] on failure); the repository
 * collapses that into the domain [com.snabbit.runner.shared.core.result.RunnerActionError].
 * `suspend` + main-safe (the Ktor engine runs off the main thread).
 */
internal interface ProfileRemoteDataSource {
    suspend fun getProfile(): Result<RunnerProfile, NetworkError>
}
