package com.snabbit.runner.shared.features.tiering.di

import com.snabbit.runner.shared.features.tiering.data.DefaultTieringDataSource
import com.snabbit.runner.shared.features.tiering.data.TieringDataSource
import com.snabbit.runner.shared.features.tiering.presentation.TieringAnalytics
import com.snabbit.runner.shared.features.tiering.presentation.viewmodel.TieringViewModel
import org.koin.core.module.dsl.viewModel
import org.koin.dsl.module

/**
 * Koin bindings for the tiering feature. The DataSource folds the Dart-fed
 * `RunnerStateStore` + `RunnerProfileStore` (both `single`s in core/profile
 * modules); the ViewModel is host-resolved via `koinViewModel()`.
 */
val tieringModule = module {
    single<TieringDataSource> {
        DefaultTieringDataSource(
            runnerState = get(),
            profileStore = get(),
            dispatchers = get(),
            currentTimeMs = get(),
            logger = get(),
        )
    }
    single { TieringAnalytics(get()) }
    viewModel { TieringViewModel(dataSource = get(), analytics = get(), store = get(), nav = get()) }
}
