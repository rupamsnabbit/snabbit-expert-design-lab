package com.snabbit.runner.shared.features.home.seeyoutomorrow.di

import com.snabbit.runner.shared.features.home.seeyoutomorrow.data.SeeYouTomorrowProjector
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.SupervisorJob
import org.koin.dsl.module

/**
 * Koin wiring for the Home `RUNNER_SEE_YOU_TOMORROW` takeover card — just its
 * read-side [SeeYouTomorrowProjector] (no data seam: the card's two CTAs reuse
 * existing nav effects). Own supervisor scope so envelope collection survives VM
 * recreation, matching `suspendedModule`. Registered in `KmpBootstrap.initialize`.
 */
val seeYouTomorrowModule = module {
    single {
        SeeYouTomorrowProjector(
            store = get(),
            scope = CoroutineScope(SupervisorJob()),
        )
    }
}
