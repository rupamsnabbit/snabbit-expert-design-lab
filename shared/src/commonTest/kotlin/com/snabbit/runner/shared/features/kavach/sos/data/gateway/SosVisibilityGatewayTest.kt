package com.snabbit.runner.shared.features.kavach.sos.data.gateway

import com.snabbit.runner.shared.core.FakeLogger
import com.snabbit.runner.shared.core.runnerstate.RunnerStateStore
import com.snabbit.runner.shared.features.kavach.testAppDispatchers
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals

/**
 * Fail-OPEN by design: only an explicit `visible: false` hides the SOS button. Absent, malformed, or
 * not-yet-loaded state must keep it shown — a parse problem must never remove a safety affordance.
 */
class SosVisibilityGatewayTest {


    private fun store(envelope: String?): RunnerStateStore {
        val s = RunnerStateStore(FakeLogger())
        envelope?.let { s.pushState(it) }
        return s
    }

    @Test
    fun noEnvelopeYet_isVisible() = runTest {
        val g = SosVisibilityGateway(store(null), testAppDispatchers(UnconfinedTestDispatcher(testScheduler)))
        runCurrent()
        assertEquals(true, g.visible.value)
    }

    @Test
    fun explicitFalse_hides() = runTest {
        val env = """{"widget_name":"RUNNER_HOME","widget_data":{"sos_visibility":{"visible":false,"reason":"OUTSIDE_WINDOW"}}}"""
        val g = SosVisibilityGateway(store(env), testAppDispatchers(UnconfinedTestDispatcher(testScheduler)))
        runCurrent()
        assertEquals(false, g.visible.value)
    }

    @Test
    fun explicitTrue_shows() = runTest {
        val env = """{"widget_name":"RUNNER_HOME","widget_data":{"sos_visibility":{"visible":true,"reason":"LOGGED_IN"}}}"""
        val g = SosVisibilityGateway(store(env), testAppDispatchers(UnconfinedTestDispatcher(testScheduler)))
        runCurrent()
        assertEquals(true, g.visible.value)
    }

    @Test
    fun fieldAbsent_isVisible() = runTest {
        // Backward compatibility: envelopes predating the flag must keep the button.
        val env = """{"widget_name":"RUNNER_HOME","widget_data":{"job_id":7}}"""
        val g = SosVisibilityGateway(store(env), testAppDispatchers(UnconfinedTestDispatcher(testScheduler)))
        runCurrent()
        assertEquals(true, g.visible.value)
    }

    @Test
    fun malformedSlice_isVisible() = runTest {
        // Wrong shape (a string where an object belongs) must not hide SOS.
        val env = """{"widget_name":"RUNNER_HOME","widget_data":{"sos_visibility":"nope"}}"""
        val g = SosVisibilityGateway(store(env), testAppDispatchers(UnconfinedTestDispatcher(testScheduler)))
        runCurrent()
        assertEquals(true, g.visible.value)
    }
}
