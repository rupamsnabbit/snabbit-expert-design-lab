package com.snabbit.runner.shared.features.gamification.di

import com.snabbit.runner.shared.features.gamification.data.GamificationProjector
import com.snabbit.runner.shared.features.gamification.presentation.postaction.PostActionCoordinator
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.SupervisorJob
import org.koin.dsl.module

/**
 * Koin wiring for the gamification feature:
 *  - [GamificationProjector] — read model that folds the `current_state`
 *    envelope. Given its own supervisor scope so envelope collection survives VM
 *    recreation, mirroring the `ShiftProjector` / `LunchProjector` bindings.
 *  - [PostActionCoordinator] — the mount-once post-action overlay orchestrator.
 *
 * Registered in `KmpBootstrap.initialize`.
 */
val gamificationModule = module {
    single {
        GamificationProjector(
            store = get(),
            scope = CoroutineScope(SupervisorJob()),
            currentTimeMs = get(),
            crashReporter = get(),
        )
    }
    single { PostActionCoordinator() }
}
