package com.snabbit.runner.shared.features.job.data.state

import com.snabbit.runner.shared.core.runnerstate.RunnerState
import kotlinx.coroutines.flow.StateFlow

/**
 * The seam between the Job feature and however the runner's `current_state` is
 * obtained. **This is the polling → MQTT swap point.**
 *
 * Today [BridgeRunnerStateSource] delegates to [com.snabbit.runner.shared.core.runnerstate.RunnerStateStore]
 * (the envelope Dart pushes over the bridge from its `current_state` polling).
 * When the migration lands, an `MqttRunnerStateSource` (or a KMP-native HTTP
 * poller) implements this same interface and is bound in `jobModule` instead —
 * no ViewModel or screen change.
 *
 * [state] replays its latest value to new collectors (hot), so a screen mounting
 * mid-shift sees the live state immediately.
 */
interface RunnerStateSource {
    /** The latest runner state envelope, or null before the first emission. */
    val state: StateFlow<RunnerState?>

    /** Ask the source to refresh now (pull-to-refresh / cold mount). Fire-and-forget. */
    fun requestRefresh()

    /**
     * Signal a state-mutating action just succeeded ([action] = a telemetry label),
     * so the realtime engine arms its post-action fallback (feature #4). Distinct
     * from [requestRefresh] (an eager refetch) — this is a *timed* safety net that
     * only fetches if MQTT doesn't deliver the transition. Default no-op: sources
     * with no engine behind them (tests, non-MQTT) ignore it.
     */
    fun onPostAction(action: String) {}
}
