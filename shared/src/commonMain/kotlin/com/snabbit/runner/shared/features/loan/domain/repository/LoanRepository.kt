package com.snabbit.runner.shared.features.loan.domain.repository

import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.core.result.RunnerActionError
import com.snabbit.runner.shared.features.loan.domain.model.LoanDetails

/**
 * Domain contract for reading the runner's loan details. Returns the generic
 * [RunnerActionError] buckets the sheet needs (retry / message) — no HTTP types
 * leak into domain or presentation.
 */
interface LoanRepository {
    suspend fun getLoanDetails(): Result<LoanDetails, RunnerActionError>
}
