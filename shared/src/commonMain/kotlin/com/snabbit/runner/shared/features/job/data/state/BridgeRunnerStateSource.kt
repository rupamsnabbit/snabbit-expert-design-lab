package com.snabbit.runner.shared.features.job.data.state

import com.snabbit.runner.shared.core.runnerstate.RunnerState
import com.snabbit.runner.shared.core.runnerstate.RunnerStateStore
import kotlinx.coroutines.flow.StateFlow

/**
 * Default [RunnerStateSource] for the transition period: reads the envelope
 * Dart pushes into [RunnerStateStore] over the existing bridge, and forwards
 * [requestRefresh] back to Dart's `current_state` re-fetch.
 *
 * This is the layer the polling → MQTT migration replaces — swap the binding in
 * `jobModule` for an MQTT-backed source and nothing downstream changes.
 */
class BridgeRunnerStateSource(
    private val store: RunnerStateStore,
) : RunnerStateSource {

    override val state: StateFlow<RunnerState?> get() = store.state

    override fun requestRefresh() = store.requestRefresh()

    override fun onPostAction(action: String) = store.onPostAction(action)
}
