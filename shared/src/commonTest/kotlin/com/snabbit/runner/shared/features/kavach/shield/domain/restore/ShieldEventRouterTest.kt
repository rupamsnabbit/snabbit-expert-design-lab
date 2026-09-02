package com.snabbit.runner.shared.features.kavach.shield.domain.restore

import com.safetykavach.shield.core.event.ShieldEvent
import com.safetykavach.shield.core.model.RecordingState
import com.safetykavach.shield.core.model.SafetyPermission
import com.safetykavach.shield.core.model.SafetyPermissionStatus
import com.safetykavach.shield.core.model.SafetyShieldErrorCode
import com.snabbit.runner.shared.features.kavach.FakeAnalyticsTracker
import com.snabbit.runner.shared.features.kavach.FakeShieldController
import com.snabbit.runner.shared.features.kavach.testAppDispatchers
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class ShieldEventRouterTest {

    private val shield = FakeShieldController()
    private val analytics = FakeAnalyticsTracker()

    // Shares the test scheduler so runCurrent() flushes the router's collectors.
    private fun TestScope.router() =
        ShieldEventRouter(shield, analytics, testAppDispatchers(UnconfinedTestDispatcher(testScheduler)))

    @Test
    fun recordingStart_firesStarted() = runTest {
        router()
        shield.recordingStateFlow.value = RecordingState.RECORDING
        runCurrent()
        val e = analytics.last("expert_shield_started")
        assertTrue(e != null)
        assertEquals("recording", e.props["mode"])
    }

    @Test
    fun recordingPauseThenResume_firesPausedThenResumed() = runTest {
        router()
        shield.recordingStateFlow.value = RecordingState.RECORDING
        runCurrent()
        shield.recordingStateFlow.value = RecordingState.PAUSED
        runCurrent()
        shield.recordingStateFlow.value = RecordingState.RECORDING
        runCurrent()
        assertEquals(
            listOf("expert_shield_started", "expert_shield_paused", "expert_shield_resumed"),
            analytics.names(),
        )
    }

    @Test
    fun idleRecordingState_firesNothing() = runTest {
        router()
        // Initial IDLE is the seed; no transition to report.
        runCurrent()
        assertTrue(analytics.tracked.isEmpty())
    }

    @Test
    fun permissionStatusEvent_firesPermissionChanged() = runTest {
        router()
        shield.eventsFlow.emit(
            ShieldEvent.PermissionStatus(SafetyPermission.MICROPHONE, SafetyPermissionStatus.GRANTED),
        )
        runCurrent()
        val e = analytics.last("expert_shield_permission_changed")
        assertTrue(e != null)
        assertEquals("microphone", e.props["permission"])
        assertEquals("granted", e.props["status"])
        assertEquals("runtime_change", e.props["context"])
    }

    @Test
    fun errorEvent_firesShieldError_withCodeAndMessage() = runTest {
        router()
        shield.eventsFlow.emit(
            ShieldEvent.Error(SafetyShieldErrorCode.RECORDING_FAILED, "mic busy", details = "code=13"),
        )
        runCurrent()
        val e = analytics.last("expert_shield_error")
        assertTrue(e != null)
        assertEquals("recording_failed", e.props["error_code"])
        assertEquals("mic busy", e.props["error_message"])
        assertEquals("code=13", e.props["error_details"])
    }

    @Test
    fun unmappedEvent_firesNothing() = runTest {
        router()
        shield.eventsFlow.emit(ShieldEvent.NotificationAction(action = "confirm", source = "n", timestamp = 0L))
        runCurrent()
        assertTrue(analytics.tracked.isEmpty())
    }
}
