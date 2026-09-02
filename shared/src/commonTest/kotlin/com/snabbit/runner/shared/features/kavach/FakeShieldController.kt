package com.snabbit.runner.shared.features.kavach

import com.safetykavach.shield.core.ShieldController
import com.safetykavach.shield.core.event.ShieldEvent
import com.safetykavach.shield.core.model.DetectionThresholds
import com.safetykavach.shield.core.model.MonitoringState
import com.safetykavach.shield.core.model.RecordingState
import com.safetykavach.shield.core.model.SafetyPermission
import com.safetykavach.shield.core.model.SafetyPermissionStatus
import com.safetykavach.shield.core.model.SafetyState
import com.safetykavach.shield.core.model.ShieldGates
import com.safetykavach.shield.core.model.ShieldConfig
import com.safetykavach.shield.core.model.ShieldMlConfig
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow

/** Deterministic fake plugin engine — records the command call order for adapter tests. */
class FakeShieldController : ShieldController {
    /** Ordered log of the commands invoked (method names). */
    val calls = mutableListOf<String>()

    // Mutable backers so tests can drive plugin-state transitions.
    val shieldStateFlow = MutableStateFlow(SafetyState.IDLE)
    val recordingStateFlow = MutableStateFlow(RecordingState.IDLE)
    val monitoringStateFlow = MutableStateFlow(MonitoringState.IDLE)
    override val shieldState: StateFlow<SafetyState> = shieldStateFlow
    override val recordingState: StateFlow<RecordingState> = recordingStateFlow
    override val monitoringState: StateFlow<MonitoringState> = monitoringStateFlow

    /** Emit here to drive event-collecting consumers (SoS coordinator, upload coordinator, router). */
    val eventsFlow = MutableSharedFlow<ShieldEvent>(extraBufferCapacity = 16)
    override val events: SharedFlow<ShieldEvent> = eventsFlow

    /** Telemetry stream (#5 split); separate from [eventsFlow]. */
    val instrumentationFlow = MutableSharedFlow<ShieldEvent>(extraBufferCapacity = 16)
    override val instrumentation: SharedFlow<ShieldEvent> = instrumentationFlow

    /** Set to make [initialize] throw — drives the activate() failure path (IG-08). */
    var failOnInitialize: Throwable? = null

    override suspend fun initialize(config: ShieldConfig) {
        calls += "initialize"
        failOnInitialize?.let { throw it }
    }
    override suspend fun configureMl(config: ShieldMlConfig) { calls += "configureMl" }
    /** [startedJobId] records what the arm sites handed down — the clip-stamp contract (ECPO-986). */
    var startedJobId: Int? = null
    /** Last gates the host pushed — the tier-permission contract. */
    var lastGates: ShieldGates? = null
    // Deliberately NOT in `calls`: it is configuration, not a ladder command — recording it would
    // break every exact-ladder assertion for no signal.
    override suspend fun setGates(gates: ShieldGates) { lastGates = gates }

    override suspend fun onJobStarted(jobId: Int?) { calls += "onJobStarted"; startedJobId = jobId }
    override suspend fun onJobEnded() { calls += "onJobEnded" }
    override suspend fun shutdown() { calls += "shutdown" }
    override suspend fun updateAudioConfig(durationSec: Int, intervalSec: Int) { calls += "updateAudioConfig" }
    override suspend fun updateDetectionThresholds(thresholds: DetectionThresholds) { calls += "updateDetectionThresholds" }
    override suspend fun checkPermissions(types: Set<SafetyPermission>): Map<SafetyPermission, SafetyPermissionStatus> {
        calls += "checkPermissions"; return emptyMap()
    }
    override suspend fun requestPermissions(types: Set<SafetyPermission>): Map<SafetyPermission, SafetyPermissionStatus> {
        calls += "requestPermissions"; return emptyMap()
    }
    override suspend fun startAccelerometerOnly() { calls += "startAccelerometerOnly" }
    override suspend fun startMonitoringOnly() { calls += "startMonitoringOnly" }
    override suspend fun downgradeToAccelerometer() { calls += "downgradeToAccelerometer" }
    override suspend fun startRecording() { calls += "startRecording" }
    override suspend fun stopRecording() { calls += "stopRecording" }
    override suspend fun discardCurrentRecording() { calls += "discardCurrentRecording" }
    override suspend fun startMonitoring() { calls += "startMonitoring" }
    override suspend fun stopMonitoring() { calls += "stopMonitoring" }
    override suspend fun confirmSoS() { calls += "confirmSoS" }
    override suspend fun denySoS() { calls += "denySoS" }
    override suspend fun deescalateSoS() { calls += "deescalateSoS" }
    override suspend fun triggerManualSoS() { calls += "triggerManualSoS" }
    override suspend fun discardAESKey() { calls += "discardAESKey" }
}
