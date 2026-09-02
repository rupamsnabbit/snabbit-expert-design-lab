package com.snabbit.runner.shared.features.loan.di

import com.snabbit.runner.shared.features.loan.data.remote.LoanRemoteDataSource
import com.snabbit.runner.shared.features.loan.data.remote.LoanRemoteDataSourceImpl
import com.snabbit.runner.shared.features.loan.data.repository.LoanRepositoryImpl
import com.snabbit.runner.shared.features.loan.domain.repository.LoanRepository
import com.snabbit.runner.shared.features.loan.domain.usecase.GetLoanDetailsUseCase
import org.koin.dsl.module

/**
 * Koin wiring for the Loan feature: the `loan_details`-backed data source,
 * repository, and [GetLoanDetailsUseCase] the Profile ViewModel resolves for the
 * Get-loan bottom sheet. Registered in `KmpBootstrap.initialize`. Mirrors
 * `profileModule`.
 */
val loanModule = module {
    single<LoanRemoteDataSource> { LoanRemoteDataSourceImpl(httpClient = get()) }
    single<LoanRepository> { LoanRepositoryImpl(remote = get()) }
    factory { GetLoanDetailsUseCase(repository = get()) }
}
