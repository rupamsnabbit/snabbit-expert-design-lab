package com.snabbit.runner.shared.features.support.di

import com.snabbit.runner.shared.features.support.data.HelplineRepository
import com.snabbit.runner.shared.features.support.data.HelplineRepositoryImpl
import org.koin.dsl.module

/**
 * Koin wiring for the shared support feature — the [HelplineRepository] backing the
 * "Need help?" sheet ([com.snabbit.runner.shared.features.support.ui.NeedHelpSheet]).
 * Registered in `KmpBootstrap.initialize`.
 */
val supportModule = module {
    single<HelplineRepository> {
        HelplineRepositoryImpl(httpClient = get(), remoteConfig = get(), crashReporter = get())
    }
}
