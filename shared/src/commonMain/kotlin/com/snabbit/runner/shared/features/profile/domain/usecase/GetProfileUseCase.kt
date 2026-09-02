package com.snabbit.runner.shared.features.profile.domain.usecase

import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.core.result.RunnerActionError
import com.snabbit.runner.shared.features.profile.domain.model.RunnerProfile
import com.snabbit.runner.shared.features.profile.domain.repository.ProfileRepository

/**
 * Loads the runner profile for the Profile screen (initial load, Retry, and
 * pull-to-refresh all go through here). A thin, stateless wrapper over
 * [ProfileRepository] — the seam tests fake and the ViewModel calls.
 */
class GetProfileUseCase(
    private val repository: ProfileRepository,
) {
    suspend operator fun invoke(): Result<RunnerProfile, RunnerActionError> =
        repository.getProfile()
}
