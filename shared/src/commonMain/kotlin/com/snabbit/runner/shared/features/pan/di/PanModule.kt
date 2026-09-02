package com.snabbit.runner.shared.features.pan.di

import com.snabbit.runner.shared.features.pan.data.remote.PanRemoteDataSource
import com.snabbit.runner.shared.features.pan.data.remote.PanRemoteDataSourceImpl
import com.snabbit.runner.shared.features.pan.data.repository.PanRepositoryImpl
import com.snabbit.runner.shared.features.pan.domain.repository.PanRepository
import com.snabbit.runner.shared.features.pan.domain.usecase.UpdatePanUseCase
import org.koin.dsl.module

/**
 * Koin wiring for the PAN feature: the onboarding-host-backed data source,
 * repository, and [UpdatePanUseCase] the Profile ViewModel resolves for the PAN
 * nudge sheet. Registered in `KmpBootstrap.initialize`. Mirrors `loanModule`.
 */
val panModule = module {
    single<PanRemoteDataSource> { PanRemoteDataSourceImpl(httpClient = get()) }
    single<PanRepository> { PanRepositoryImpl(remote = get()) }
    factory { UpdatePanUseCase(repository = get()) }
}
