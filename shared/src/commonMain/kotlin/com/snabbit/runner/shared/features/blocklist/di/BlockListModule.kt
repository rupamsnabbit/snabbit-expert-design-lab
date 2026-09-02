package com.snabbit.runner.shared.features.blocklist.di

import com.snabbit.runner.shared.features.blocklist.data.repository.BlockListRepositoryImpl
import com.snabbit.runner.shared.features.blocklist.domain.repository.BlockListRepository
import org.koin.dsl.module

/**
 * Koin wiring for the Block list feature. Provides the production [BlockListRepository] backed by
 * the network module's `SnabbitHttpClient` (resolved from `coreModule`). Registered in
 * `KmpBootstrap.initialize`.
 *
 * [BlockListViewModel] is intentionally NOT here — like the language/job modules it is constructed
 * by the host with its UI [kotlinx.coroutines.CoroutineScope] + per-launch [BlockListStrings].
 */
val blockListModule = module {
    single<BlockListRepository> {
        BlockListRepositoryImpl(httpClient = get(), crashReporter = get())
    }
}
