package com.snabbit.runner.shared.core.connectivity

import kotlinx.coroutines.flow.StateFlow

/** Network reachability. `online` emits the current value on collect and updates on change. */
interface Connectivity {
    val online: StateFlow<Boolean>
}

/** Platform factory (Android needs a Context; iOS is no-arg) — mirrors `ShieldDbDriverFactory`. */
expect class ConnectivityFactory {
    fun create(): Connectivity
}
