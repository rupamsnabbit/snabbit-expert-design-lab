package com.snabbit.runner.shared.features.periodleave.di

import com.snabbit.runner.shared.features.periodleave.PeriodLeaveStore
import com.snabbit.runner.shared.features.periodleave.data.remote.PeriodLeaveRemoteDataSource
import com.snabbit.runner.shared.features.periodleave.data.remote.PeriodLeaveRemoteDataSourceImpl
import com.snabbit.runner.shared.features.periodleave.data.repository.PeriodLeaveRepositoryImpl
import com.snabbit.runner.shared.features.periodleave.domain.repository.PeriodLeaveRepository
import org.koin.dsl.module

/**
 * Koin wiring for the PeriodLeave feature. Interface→impl bindings with no
 * per-launch state — mirrors the Shift / Attendance modules.
 *
 * Registered in `KmpBootstrap.initialize`.
 */
val periodLeaveModule = module {
    single<PeriodLeaveRemoteDataSource> {
        PeriodLeaveRemoteDataSourceImpl(httpClient = get())
    }
    single<PeriodLeaveRepository> {
        PeriodLeaveRepositoryImpl(remote = get())
    }
    // Bridge-fed period-leave availability (Dart pushes; KMP reads). Fed by ProfileSyncPlugin.
    single { PeriodLeaveStore(logger = get()) }
}
