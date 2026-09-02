package com.snabbit.runner.kmp_bridge

import android.os.Handler
import android.os.Looper
import com.snabbit.runner.shared.core.analytics.AnalyticsTracker
import com.snabbit.runner.shared.core.background.SnabbitForegroundService
import com.snabbit.runner.shared.core.realtime.RealtimeConfigStore
import com.snabbit.runner.shared.core.realtime.WakeReason
import com.snabbit.runner.shared.core.runnerstate.RunnerStateStore
import com.snabbit.runner.shared.features.autoot.data.AutoOtCoordinator
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.koin.core.component.KoinComponent
import org.koin.core.component.inject

/**
 * Owns the `com.snabbit.runner/runner_state` MethodChannel — the bridge that
 * mirrors the Flutter `RunnerRtDataProvider`'s `current_state` envelope into the
 * KMP [RunnerStateStore] so Compose Multiplatform surfaces can observe it.
 *
 * Bidirectional:
 *  - Dart → KMP: `pushState` writes the latest envelope into [RunnerStateStore].
 *    Synchronous `MutableStateFlow.value` write, no main-thread hop needed
 *    (unlike an `EventChannel.EventSink`, which must be fed on the main thread
 *    — see `AuthPlugin`).
 *  - KMP → Dart: [RunnerStateStore.requestRefresh] (called by Compose VMs) wakes
 *    the in-process realtime engine directly when it is running (MQTT cohort —
 *    no Dart involved), and otherwise fires `requestRefresh` over the channel:
 *    Dart re-fetches `current_state` for the polling cohort, or — cohort with a
 *    dead engine — `startService(ACTION_WAKE)`s the engine back up. Either way
 *    the refreshed envelope flows back through `pushState`/the projector. The
 *    bridge is bound on attach and cleared on detach, so a late call after
 *    detach no-ops in the store. Both branches are posted to the main looper:
 *    Compose may call [requestRefresh] from any dispatcher, and both
 *    `MethodChannel.invokeMethod` and the engine's transport expect the
 *    platform thread (the service's own wake calls run there).
 */
class RunnerStatePlugin : FlutterPlugin, KoinComponent {

    private val store: RunnerStateStore by inject()
    private val autoOtCoordinator: AutoOtCoordinator by inject()
    private val analytics: AnalyticsTracker by inject()

    /** Holds `expert_mqtt_health_analytics_enabled` — the kill-switch every realtime-health event
     *  answers to, so a pathological volume can be silenced without a store release. */
    private val configStore: RealtimeConfigStore by inject()

    private var channel: MethodChannel? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler(::handle)
        }
        // Cohort short-circuit: when the realtime engine is in-process, the old KMP → Dart →
        // `RealtimeChannel.wake()` → back-into-this-process route crossed two platform channels
        // and two Dart-side RC gates that could silently swallow the request. Call the engine
        // directly, exactly as bindPostAction below does. Engine null → the Dart path is still
        // the right one: it can do the two things a direct call can't — fetch for the polling
        // cohort, and restart a dead engine for the realtime one.
        store.bind {
            mainHandler.post {
                val engine = SnabbitForegroundService.activeEngine
                if (engine != null) engine.onWakeSignal(WakeReason.USER_REFRESH)
                else channel?.invokeMethod("requestRefresh", null)
            }
        }
        // Feature #4: route post-action signals straight to the realtime engine's
        // deadline (NOT over the Dart channel like requestRefresh). Engine confines the work.
        store.bindPostAction { action ->
            val engine = SnabbitForegroundService.activeEngine
            if (engine != null) {
                engine.onPostAction(action)
            } else {
                // No engine ⇒ no deadline, no fallback fetch — and, because the fallback event
                // fires INSIDE the engine, no telemetry either: this branch was invisible, so the
                // measured fallback rate silently excluded every action taken without a live
                // engine. Count it here; recovery for this population is owned by the Dart
                // resume-gap reopen, not this bridge. (Expected ~never for the cohort — the FGS
                // outlives the UI — which is exactly why it needs counting, not assuming.)
                if (configStore.healthAnalyticsEnabled.value) {
                    analytics.track(ANALYTICS_POST_ACTION_NO_ENGINE, mapOf("action" to action))
                }
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        store.bind(null)
        store.bindPostAction(null)
        channel?.setMethodCallHandler(null)
        channel = null
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pushState" -> {
                val json = call.argument<String>("json")
                if (json.isNullOrBlank()) {
                    result.error("INVALID_ARGS", "pushState requires non-blank json", null)
                    return
                }
                store.pushState(json)
                result.success(null)
            }
            // Server cancelled the OT offer (AUTO_OT_CANCELLED push) → flip the KMP Auto-OT sheet
            // to expired (the coordinator applies its own active-offer guard).
            "autoOtCancelled" -> {
                autoOtCoordinator.onCancelled()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private companion object {
        const val CHANNEL = "com.snabbit.runner/runner_state"

        /** A post-action fired while no realtime engine was alive to arm its fallback. */
        const val ANALYTICS_POST_ACTION_NO_ENGINE = "mqtt_post_action_no_engine"
    }
}
