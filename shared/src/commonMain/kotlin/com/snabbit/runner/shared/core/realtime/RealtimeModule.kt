package com.snabbit.runner.shared.core.realtime

import org.koin.dsl.module

/**
 * Realtime bindings (registered in KmpBootstrap since WS4). The ENGINE stays
 * host-constructed by SnabbitForegroundService via RealtimeHost — it needs the
 * platform transport, a Room store built from Context, and a service-scoped
 * CoroutineScope (same host-constructed pattern as ProfileGateway).
 */
val realtimeModule = module {
    single { RealtimeConfigStore(store = get(), logger = get()) }
    single { CurrentStateReconciler(http = get(), logger = get()) }
    // Debug-only diagnostics (Profile footer, non-prod): fed by RealtimeHost.
    single { RealtimeDiagnostics() }
    // The engine→sink→store writer inversion is retired: the DB is now the single
    // source of truth and RunnerStateProjector feeds the read model by observing
    // the store. The projector is host-constructed (it needs the same runnerId-keyed
    // SnapshotStore instance the engine writes), so it isn't a Koin single here.
}
