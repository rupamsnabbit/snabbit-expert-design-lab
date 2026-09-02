package com.snabbit.runner.shared.features.kavach.shield.domain.upload

import com.snabbit.runner.shared.features.kavach.FakeConnectivity
import com.snabbit.runner.shared.features.kavach.testAppDispatchers
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals

class ShieldUploadReconnectTriggerTest {

    private fun TestScope.trigger(conn: FakeConnectivity, drain: suspend () -> Unit) =
        ShieldUploadReconnectTrigger(conn, drain, testAppDispatchers(UnconfinedTestDispatcher(testScheduler)))

    @Test
    fun drainsOnEachReconnectEdge_butNotTheInitialValue() = runTest {
        var drains = 0
        val conn = FakeConnectivity(initial = false)
        trigger(conn) { drains++ }
        runCurrent()
        assertEquals(0, drains)             // initial value dropped
        conn.flow.value = true; runCurrent()
        assertEquals(1, drains)             // first reconnect
        conn.flow.value = false; runCurrent()
        conn.flow.value = true; runCurrent()
        assertEquals(2, drains)             // second reconnect
    }

    @Test
    fun launchWhileOnline_doesNotDrain() = runTest {
        var drains = 0
        trigger(FakeConnectivity(initial = true)) { drains++ }
        runCurrent()
        assertEquals(0, drains)             // coordinator already flushes the backlog at start
    }
}
