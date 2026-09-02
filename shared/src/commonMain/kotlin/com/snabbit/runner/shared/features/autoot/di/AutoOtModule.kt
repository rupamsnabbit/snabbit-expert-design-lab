@file:OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)

package com.snabbit.runner.shared.features.autoot.di

import com.snabbit.runner.shared.core.AppDispatchers
import com.snabbit.runner.shared.features.autoot.data.AutoOtCoordinator
import com.snabbit.runner.shared.features.autoot.data.remote.AutoOtRemoteDataSource
import com.snabbit.runner.shared.features.autoot.data.remote.AutoOtRemoteDataSourceImpl
import com.snabbit.runner.shared.features.autoot.data.repository.AutoOtRepositoryImpl
import com.snabbit.runner.shared.features.autoot.domain.repository.AutoOtRepository
import com.snabbit.runner.shared.features.autoot.presentation.AutoOtViewModel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.SupervisorJob
import org.koin.core.module.dsl.viewModel
import org.koin.dsl.module

/**
 * Auto-OT feature graph. The [AutoOtCoordinator] owns its supervisor scope so it observes the
 * runner-state stream for the shell's whole lifetime (survives VM recreation) — mirrors how
 * `homeModule` registers `ShiftProjector`. The scope is confined to a single thread
 * (`default.limitedParallelism(1)`) so the stream collector, `onAttendanceMarked` and `onCancelled`
 * all mutate the coordinator's fields serially (no data race). The VM is fed the coordinator's
 * `trigger` flow + `onPostAction`/`onConsumed` callbacks (not the coordinator) to stay decoupled.
 */
val autoOtModule = module {
    single<AutoOtRemoteDataSource> { AutoOtRemoteDataSourceImpl(httpClient = get()) }
    single<AutoOtRepository> { AutoOtRepositoryImpl(remote = get()) }
    single {
        AutoOtCoordinator(
            store = get(),
            repository = get(),
            appConfig = get(),
            remoteConfig = get(),
            scope = CoroutineScope(SupervisorJob() + get<AppDispatchers>().default.limitedParallelism(1)),
        )
    }
    viewModel {
        val coordinator = get<AutoOtCoordinator>()
        AutoOtViewModel(
            trigger = coordinator.trigger,
            repository = get(),
            analytics = get(),
            onPostAction = coordinator::onPostAction,
            onConsumed = coordinator::onOfferConsumed,
        )
    }
}
