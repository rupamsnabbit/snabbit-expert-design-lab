package com.snabbit.runner.shared.features.periodleave.domain.repository

import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.core.result.RunnerActionError
import com.snabbit.runner.shared.features.periodleave.domain.model.PeriodLeaveAvailability

/**
 * Domain port for period-leave reads. Lives in `domain` so use cases never
 * reach into the data layer; the production implementation in
 * `data/repository/` translates the data-layer `NetworkError` into the
 * generic [RunnerActionError] buckets.
 */
interface PeriodLeaveRepository {
    suspend fun getAvailability(): Result<PeriodLeaveAvailability, RunnerActionError>
}
