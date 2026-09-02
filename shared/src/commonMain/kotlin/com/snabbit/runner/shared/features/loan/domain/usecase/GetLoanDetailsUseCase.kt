package com.snabbit.runner.shared.features.loan.domain.usecase

import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.core.result.RunnerActionError
import com.snabbit.runner.shared.features.loan.domain.model.LoanDetails
import com.snabbit.runner.shared.features.loan.domain.repository.LoanRepository

/**
 * Fetches the runner's loan details for the Get-loan bottom sheet. Thin stateless
 * wrapper over [LoanRepository] — the seam the ViewModel calls (and tests fake).
 */
class GetLoanDetailsUseCase(
    private val repository: LoanRepository,
) {
    suspend operator fun invoke(): Result<LoanDetails, RunnerActionError> =
        repository.getLoanDetails()
}
