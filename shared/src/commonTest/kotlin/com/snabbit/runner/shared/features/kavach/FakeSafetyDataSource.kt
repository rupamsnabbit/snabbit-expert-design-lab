package com.snabbit.runner.shared.features.kavach

import com.safetykavach.shield.core.event.ShieldEvent
import com.safetykavach.shield.core.model.MonitoringState
import com.safetykavach.shield.core.model.RecordingState
import com.safetykavach.shield.core.model.SafetyState
import com.snabbit.runner.shared.features.kavach.shared.data.SafetyCondition
import com.snabbit.runner.shared.features.kavach.shared.data.SafetyDataSource
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow

/** Deterministic fake — records action calls; drives plugin state/events/[conditions] from mutable flows. */
class FakeSafetyDataSource : SafetyDataSource {
    var activateCalls = 0
    var startForJobCalls = 0
    var startForJobArms = true   // false → startForJob() returns false (simulates current_state jobId lag)
    var activateArms = true      // false → activate() returns false (same jobId lag, manual path)
    var endForJobCalls = 0
    var triggerSosCalls = 0
    var callSosTeamCalls = 0
    var endSosCalls = 0
    var throwOnActivate = false
    var activationSheetShouldShow = true
    var markActivationShownCalls = 0

    // Test-drivable plugin surface.
    val shieldStateFlow = MutableStateFlow(SafetyState.IDLE)
    val recordingStateFlow = MutableStateFlow(RecordingState.IDLE)
    val monitoringStateFlow = MutableStateFlow(MonitoringState.IDLE)
    val eventsFlow = MutableSharedFlow<ShieldEvent>(extraBufferCapacity = 8)
    val conditionState = MutableStateFlow(SafetyCondition.NONE)

    override val shieldState: StateFlow<SafetyState> get() = shieldStateFlow
    override val recordingState: StateFlow<RecordingState> get() = recordingStateFlow
    override val monitoringState: StateFlow<MonitoringState> get() = monitoringStateFlow
    override val events: SharedFlow<ShieldEvent> get() = eventsFlow

    override suspend fun activate(): Boolean {
        activateCalls++
        if (throwOnActivate) throw IllegalStateException("activate failed")
        if (!activateArms) return false   // jobId-lag no-op, mirrors startForJobArms
        // Simulate the engine transitioning into monitoring+recording after a successful start.
        shieldStateFlow.value = SafetyState.MONITORING
        recordingStateFlow.value = RecordingState.RECORDING
        return true
    }

    override suspend fun shouldShowActivationSheet(): Boolean = activationSheetShouldShow

    override suspend fun markActivationSheetShown() { markActivationShownCalls++ }

    override suspend fun startForJob(): Boolean {
        startForJobCalls++
        if (throwOnActivate) throw IllegalStateException("startForJob failed")
        shieldStateFlow.value = SafetyState.MONITORING
        recordingStateFlow.value = RecordingState.RECORDING
        return startForJobArms
    }

    override suspend fun endForJob() {
        endForJobCalls++
        shieldStateFlow.value = SafetyState.IDLE
        recordingStateFlow.value = RecordingState.IDLE
        monitoringStateFlow.value = MonitoringState.IDLE
    }

    override suspend fun triggerSos() {
        triggerSosCalls++
    }

    override suspend fun callSosTeam() {
        callSosTeamCalls++
    }

    override suspend fun endSos() {
        endSosCalls++
    }

    override fun conditions(): Flow<SafetyCondition> = conditionState
}
