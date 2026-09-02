package com.snabbit.runner.shared.features.loan.data.remote

import com.snabbit.runner.shared.core.network.NetworkError
import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.features.loan.domain.model.LoanDetails

/**
 * Data-layer seam for the loan-details fetch (`GET api/v1/runners/me/loan_details`).
 * Returns the network-shaped [Result]; the repository collapses [NetworkError] into
 * the domain [com.snabbit.runner.shared.core.result.RunnerActionError].
 */
internal interface LoanRemoteDataSource {
    suspend fun getLoanDetails(): Result<LoanDetails, NetworkError>
}
