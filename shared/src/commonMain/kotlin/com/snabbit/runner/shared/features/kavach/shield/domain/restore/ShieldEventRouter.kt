package com.snabbit.runner.shared.features.kavach.shield.domain.restore

import com.safetykavach.shield.core.ShieldController
import com.safetykavach.shield.core.event.ShieldEvent
import com.safetykavach.shield.core.model.RecordingState
import com.snabbit.runner.shared.features.kavach.shared.domain.ActiveTriggerHolder
import com.snabbit.runner.shared.core.AppDispatchers
import com.snabbit.runner.shared.core.analytics.AnalyticsTracker
import kotlinx.atomicfu.atomic
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/**
 * Fans plugin signals out to product analytics (Step 9: IG-07/08/10/11 + shield errors),
 * reusing the app-wide [AnalyticsTracker] — the route table already carries every
 * `expert_shield_*` key. Read-only: observes the plugin's [RecordingState] + [ShieldEvent]s
 * and issues no commands.
 *
 * A Koin single with its own [scope]. ⚠ Self-starts collection on first injection (mirrors
 * [SosCoordinator]); hoist [start] to an app/job lifecycle point for pre-feature-load coverage
 * (follow-up, same as the coordinators).
 *
 * Scope (2a): started/resumed (IG-07), paused (IG-10), permission_changed (IG-11), error.
 * IG-08 (activation failure) fires from `SafetyDataSourceImpl.activate()` — that throw is on the
 * command call path, not here. TODO(2a-followup): `Instrumentation` → Plane-2
 * `expert_shield_native_*` (needs the plugin's eventName enumeration) + `expert_shield_stopped`
 * on job-end (2b lifecycle).
 */
class ShieldEventRouter(
    private val shield: ShieldController,
    private val analytics: AnalyticsTracker,
    dispatchers: AppDispatchers,
    private val activeTrigger: ActiveTriggerHolder = ActiveTriggerHolder(),
) {
    private val scope = CoroutineScope(SupervisorJob() + dispatchers.default)
    // Atomic CAS, not a bare flag: the KDoc invites hoisting start() to a lifecycle point, so a
    // second concurrent caller must not pass the guard and double-launch the collectors (doubled events).
    private val running = atomic(false)

    init {
        start()
    }

    /** Idempotent; launches the recording-state + event collectors. */
    fun start() {
        if (!running.compareAndSet(false, true)) return
        scope.launch {
            var previous = RecordingState.IDLE
            shield.recordingState.collect { state ->
                when (state) {
                    RecordingState.RECORDING -> analytics.track(
                        if (previous == RecordingState.PAUSED) EVENT_RESUMED else EVENT_STARTED,
                        mapOf("mode" to "recording", "trigger" to activeTrigger.value()),
                    )
                    RecordingState.PAUSED -> analytics.track(
                        EVENT_PAUSED,
                        mapOf("mode" to "recording", "reason" to "audio_interruption", "trigger" to activeTrigger.value()),
                    )
                    RecordingState.IDLE -> {}
                }
                previous = state
            }
        }
        scope.launch {
            shield.events.collect { event ->
                when (event) {
                    is ShieldEvent.PermissionStatus -> analytics.track(
                        EVENT_PERMISSION_CHANGED,
                        mapOf(
                            "permission" to event.permission.name.lowercase(),
                            "status" to event.status.name.lowercase(),
                            "context" to "runtime_change",
                        ),
                    )
                    is ShieldEvent.Error -> analytics.track(
                        EVENT_ERROR,
                        buildMap {
                            put("error_code", event.code.name.lowercase())
                            put("error_message", event.message)
                            event.details?.let { put("error_details", it) }
                        },
                    )
                    // SoS/EncryptedAudio → coordinators.
                    else -> {}
                }
            }
        }
        // Plane-2 native telemetry. The plugin has always emitted these; nothing collected them, so
        // every expert_shield_native_* route in the table was dead and the native side was invisible
        // in analytics (no detection counts, no session lifecycle, no sos_triggered).
        scope.launch {
            shield.instrumentation.collect { event ->
                // Only forward allow-listed native names; unknown ones are dropped BEFORE the strict route
                // table, which would otherwise fire an IllegalStateException per emission.
                if (event is ShieldEvent.Instrumentation && event.eventName in ROUTED_NATIVE_EVENTS) {
                    analytics.track("$NATIVE_PREFIX${event.eventName}", event.properties)
                }
            }
        }
    }

    private companion object {
        const val EVENT_STARTED = "expert_shield_started"
        const val EVENT_RESUMED = "expert_shield_resumed"
        const val EVENT_PAUSED = "expert_shield_paused"
        const val EVENT_PERMISSION_CHANGED = "expert_shield_permission_changed"
        const val EVENT_ERROR = "expert_shield_error"
        const val NATIVE_PREFIX = "expert_shield_native_"
        // Native eventNames forwarded to analytics — mirror of the SEED expert_shield_native_* keys
        // (single source of truth). A name absent here is silently dropped, never unrouted-crashed.
        val ROUTED_NATIVE_EVENTS = setOf(
            "plugin_lifecycle", "session_lifecycle", "monitoring_state", "recording_state",
            "service_state_changed", "model_load_partial_failure", "recording_scheduler_fallback_start",
            "audio_capture_stopped", "sos_triggered", "sos_resolved", "sos_escalated",
            "burst_recording", "notification_action_null_callback",
            // A notification that failed to post is a safety signal — don't drop it.
            "notification_display_failed",
            // The host closed the ML gate — proves the RC kill-switch actually took effect.
            "ml_gate_closed",
            // A tier gate blocked a ladder call. Gates are fail-closed, so a host that pushes late looks
            // exactly like a broken plugin without this.
            "host_gate_blocked",
            // The capture reader didn't drain within the bounded join — a wedged AudioRecord read.
            "audio_capture_drain_timeout",
            // The clip event overflowed the plugin's buffer, so the live upload path never saw it. The
            // sidecar sweep recovers it, but the drop itself must be visible.
            "clip_event_dropped",
        )
    }
}
