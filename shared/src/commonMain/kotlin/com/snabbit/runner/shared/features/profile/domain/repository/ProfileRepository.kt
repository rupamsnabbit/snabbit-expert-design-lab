package com.snabbit.runner.shared.features.profile.domain.repository

import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.core.result.RunnerActionError
import com.snabbit.runner.shared.features.profile.domain.model.RunnerProfile

/**
 * Domain contract for reading the runner profile. Returns the generic
 * [RunnerActionError] buckets the UI needs (retry / message) — no Ktor/HTTP
 * types leak into domain or presentation.
 */
interface ProfileRepository {
    suspend fun getProfile(): Result<RunnerProfile, RunnerActionError>
}
