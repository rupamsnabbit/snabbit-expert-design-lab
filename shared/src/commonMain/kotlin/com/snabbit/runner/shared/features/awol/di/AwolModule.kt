package com.snabbit.runner.shared.features.awol.di

import com.snabbit.runner.shared.core.alarm.AlarmController
import com.snabbit.runner.shared.features.awol.presentation.AwolAnalytics
import com.snabbit.runner.shared.features.awol.presentation.AwolViewModel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import org.koin.dsl.module

/**
 * Koin wiring for the AWOL feature. Unlike [com.snabbit.runner.shared.features.job.di.jobModule]
 * (whose ViewModel is host-constructed per launch), [AwolViewModel] binds as a
 * **single with its own long-lived scope** — the process-lived-coordinator
 * decision (TRD §8): episode memory must survive screens mounting/unmounting,
 * and the Android launcher + overlay spec need the routing signal when no UI
 * exists at all. Seams ([com.snabbit.runner.shared.features.job.data.RunnerStateSource],
 * `JobClock`, `PermissionManager`, `Logger`) resolve from the core/job modules —
 * no second state source, clock, or permission handler.
 */
val awolModule = module {
    single {
        val alarm = get<AlarmController>()
        AwolViewModel(
            source = get(),
            clock = get(),
            permissions = get(),
            analytics = AwolAnalytics(tracker = get()),
            logger = get(),
            store = get(),
            scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate),
            // Host-owned alarm (Dart plays it); the VM only signals acknowledgement.
            silenceAlarm = { alarm.silence() },
        )
    }
}
