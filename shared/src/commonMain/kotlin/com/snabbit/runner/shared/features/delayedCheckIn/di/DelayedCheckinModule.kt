package com.snabbit.runner.shared.features.job.delayedcheckin.di

import com.snabbit.runner.shared.features.job.delayedcheckin.DelayedCheckinAnalytics
import com.snabbit.runner.shared.features.job.delayedcheckin.data.remote.DelayedCheckinRemoteDataSource
import com.snabbit.runner.shared.features.job.delayedcheckin.data.remote.DelayedCheckinRemoteDataSourceImpl
import com.snabbit.runner.shared.features.job.delayedcheckin.data.repository.DelayedCheckinRepositoryImpl
import com.snabbit.runner.shared.features.job.delayedcheckin.domain.repository.DelayedCheckinRepository
import org.koin.dsl.module

/**
 * Platform-free Koin bindings for the delayed check-in feature: the remote
 * data source, repository, and analytics wrapper.
 *
 * Registered in `KmpBootstrap.initialize`'s `modules(...)` list — the only
 * aggregation point that exists on this branch.
 */
val delayedCheckinModule = module {
    single<DelayedCheckinRemoteDataSource> { DelayedCheckinRemoteDataSourceImpl(httpClient = get()) }
    single<DelayedCheckinRepository> { DelayedCheckinRepositoryImpl(remoteDataSource = get()) }
    single { DelayedCheckinAnalytics(tracker = get()) }
}
