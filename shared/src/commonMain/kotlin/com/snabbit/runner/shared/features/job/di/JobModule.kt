package com.snabbit.runner.shared.features.job.di

import com.snabbit.runner.shared.features.job.JobAnalytics
import com.snabbit.runner.shared.features.job.data.contact.CallingDataSource
import com.snabbit.runner.shared.features.job.data.contact.CallingDataSourceImpl
import com.snabbit.runner.shared.features.job.data.state.BridgeRunnerStateSource
import com.snabbit.runner.shared.features.job.data.CoreJobLocationProvider
import com.snabbit.runner.shared.features.job.data.JobActionStore
import com.snabbit.runner.shared.features.job.data.JobActionScope
import com.snabbit.runner.shared.features.job.data.JobServiceIdHolder
import com.snabbit.runner.shared.features.job.data.LocationProvider
import com.snabbit.runner.shared.features.job.data.state.RunnerStateSource
import com.snabbit.runner.shared.features.job.data.remote.JobActionRemoteDataSource
import com.snabbit.runner.shared.features.job.data.remote.JobActionRemoteDataSourceImpl
import com.snabbit.runner.shared.features.job.data.repository.JobActionRepositoryImpl
import com.snabbit.runner.shared.features.job.domain.JobClock
import com.snabbit.runner.shared.features.job.domain.repository.JobActionRepository
import com.snabbit.runner.shared.features.job.domain.systemJobClock
import org.koin.dsl.module

/**
 * Koin wiring for the Job feature. Binds the two swappable seams:
 *  - [RunnerStateSource] → [BridgeRunnerStateSource] (reads the Dart bridge today;
 *    swap to an MQTT-backed source here when the migration lands).
 *  - [JobActionRepository] → [JobActionRepositoryImpl] (data-layer error mapping,
 *    delegates raw HTTP to [JobActionRemoteDataSource]).
 *
 * [LocationProvider] → [CoreJobLocationProvider], backed by the shared `core.location`
 * module (permission-gated fused provider) — supplies the optional `location:{lat,lng}` on job
 * actions, time-bounded so a slow GPS fix never stalls the action (skips location instead).
 *
 * NOT here (host-constructed, like the language module): [JobViewModel] is built by
 * the host with its UI scope. Registered in `KmpBootstrap.initialize`. (Per-launch labels are
 * resolved in composition via `rememberJobStrings` and passed to `JobScreen`, not the ViewModel.)
 */
val jobModule = module {
    single<RunnerStateSource> { BridgeRunnerStateSource(store = get()) }
    // Shared in-flight accept/deny state — a process single so the overlay + in-app New-Job surfaces
    // share one store (an overlay accept stays in-flight, guarded, when JobActivity opens). ECPO #1.
    single { JobActionStore() }
    // The scope those in-flight POSTs run on. Process-lived on purpose — see JobActionScope: a
    // composition-scoped scope cancels mid-accept and wedges the store above permanently.
    single { JobActionScope() }
    // Runner profile service_id (Cook vs Expert), pushed from Dart via JobScreenLauncherPlugin and
    // read by both New-Job surfaces (foreground overlay + draw-over service) to pick the header glyph.
    single { JobServiceIdHolder() }
    single<JobActionRemoteDataSource> { JobActionRemoteDataSourceImpl(httpClient = get()) }
    single<JobActionRepository> {
        JobActionRepositoryImpl(remote = get(), crashReporter = get())
    }
    single<CallingDataSource> {
        CallingDataSourceImpl(httpClient = get(), crashReporter = get())
    }
    single<JobClock> { systemJobClock() }
    single<LocationProvider> { CoreJobLocationProvider(core = get(), remoteConfig = get()) }
    // Job-lifecycle instrumentation wrapper (mirrors delayedCheckinModule's DelayedCheckinAnalytics) —
    // threaded into JobViewModel + its sub-VMs by the host. The AnalyticsTracker binding is global.
    single { JobAnalytics(tracker = get()) }
}
