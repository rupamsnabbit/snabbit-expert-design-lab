package com.snabbit.runner.shared.features.periodleave

import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.core.result.RunnerActionError
import com.snabbit.runner.shared.features.periodleave.domain.model.PeriodLeaveAvailability
import com.snabbit.runner.shared.features.periodleave.domain.repository.PeriodLeaveRepository

/**
 * Test fake for [PeriodLeaveRepository]. Default returns a stock 1-of-1
 * availability so VM tests don't need to enqueue. Push canned responses via
 * [enqueue] (FIFO). Records each call in [callCount].
 */
class FakePeriodLeaveRepository : PeriodLeaveRepository {

    private val responses: ArrayDeque<Result<PeriodLeaveAvailability, RunnerActionError>> = ArrayDeque()
    var callCount: Int = 0
        private set

    fun enqueue(result: Result<PeriodLeaveAvailability, RunnerActionError>) {
        responses.addLast(result)
    }

    override suspend fun getAvailability(): Result<PeriodLeaveAvailability, RunnerActionError> {
        callCount++
        return responses.removeFirstOrNull()
            ?: Result.Ok(PeriodLeaveAvailability(maxPeriodLeaves = 1, periodLeavesTaken = 0))
    }
}
