package com.snabbit.runner.shared.features.seva.di

import com.snabbit.runner.shared.features.seva.data.remote.SevaRemoteDataSource
import com.snabbit.runner.shared.features.seva.data.remote.SevaRemoteDataSourceImpl
import com.snabbit.runner.shared.features.seva.data.repository.SevaRepositoryImpl
import com.snabbit.runner.shared.features.seva.domain.repository.SevaRepository
import org.koin.dsl.module

/**
 * Koin wiring for the Seva feature — interface→impl bindings, no per-launch
 * state, mirroring `shiftModule`. Registered in `KmpBootstrap.initialize`.
 */
val sevaModule = module {
    single<SevaRemoteDataSource> { SevaRemoteDataSourceImpl(httpClient = get()) }
    single<SevaRepository> { SevaRepositoryImpl(remote = get()) }
}
