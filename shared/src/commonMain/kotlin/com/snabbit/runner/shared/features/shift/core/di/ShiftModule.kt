package com.snabbit.runner.shared.features.shift.core.di

import com.snabbit.runner.shared.features.shift.core.data.remote.ShiftRemoteDataSource
import com.snabbit.runner.shared.features.shift.core.data.remote.ShiftRemoteDataSourceImpl
import com.snabbit.runner.shared.features.shift.core.data.repository.ShiftRepositoryImpl
import com.snabbit.runner.shared.features.shift.core.domain.repository.ShiftRepository
import com.snabbit.runner.shared.features.shift.lunch.data.LunchProjector
import com.snabbit.runner.shared.features.shift.lunch.data.remote.LunchRemoteDataSource
import com.snabbit.runner.shared.features.shift.lunch.data.remote.LunchRemoteDataSourceImpl
import com.snabbit.runner.shared.features.shift.lunch.data.repository.LunchRepositoryImpl
import com.snabbit.runner.shared.features.shift.lunch.domain.repository.LunchRepository
import com.snabbit.runner.shared.features.shift.presentation.emergencylogout.EmergencyLogoutAnalytics
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.SupervisorJob
import org.koin.dsl.module

/**
 * Koin wiring for the Shift feature — login, logout, emergency-logout, and the
 * in-shift **break (lunch)** sub-feature. One module covers all layers because
 * the bindings are interface→impl with no per-launch state; the Attendance
 * module follows the same convention.
 *
 * Registered in `KmpBootstrap.initialize`.
 */
val shiftModule = module {
    single<ShiftRemoteDataSource> {
        ShiftRemoteDataSourceImpl(httpClient = get())
    }
    single<ShiftRepository> {
        ShiftRepositoryImpl(remote = get(), logger = get())
    }

    // Emergency-logout sheet analytics (host-constructed VM in ProfileTabContent).
    single { EmergencyLogoutAnalytics(tracker = get()) }

    // --- Break (lunch) sub-feature ---
    single<LunchRemoteDataSource> {
        LunchRemoteDataSourceImpl(httpClient = get())
    }
    single<LunchRepository> {
        LunchRepositoryImpl(remote = get())
    }
    // Own supervisor scope so envelope collection survives VM recreation —
    // mirrors homeModule's ShiftProjector binding.
    single { LunchProjector(store = get(), scope = CoroutineScope(SupervisorJob()), logger = get()) }
}
