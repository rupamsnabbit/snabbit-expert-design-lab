package com.snabbit.runner.shared.features.home.suspended.di

import com.snabbit.runner.shared.features.home.suspended.data.SuspendedProjector
import com.snabbit.runner.shared.features.home.suspended.data.remote.SuspendedRemoteDataSource
import com.snabbit.runner.shared.features.home.suspended.data.remote.SuspendedRemoteDataSourceImpl
import com.snabbit.runner.shared.features.home.suspended.data.repository.SuspendedRepositoryImpl
import com.snabbit.runner.shared.features.home.suspended.domain.repository.SuspendedRepository
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.SupervisorJob
import org.koin.dsl.module

/**
 * Koin wiring for the Home `RUNNER_SUSPENDED` card — its data seam (unsuspend)
 * and its read-side [SuspendedProjector]. Interface→impl with no per-launch
 * state, matching the `shiftModule` convention. Registered in
 * `KmpBootstrap.initialize`.
 */
val suspendedModule = module {
    single<SuspendedRemoteDataSource> {
        SuspendedRemoteDataSourceImpl(httpClient = get())
    }
    single<SuspendedRepository> {
        SuspendedRepositoryImpl(remote = get())
    }
    // Own supervisor scope so envelope collection survives VM recreation —
    // mirrors shiftModule's LunchProjector binding.
    single {
        SuspendedProjector(
            store = get(),
            profileStore = get(),
            scope = CoroutineScope(SupervisorJob()),
        )
    }
}
