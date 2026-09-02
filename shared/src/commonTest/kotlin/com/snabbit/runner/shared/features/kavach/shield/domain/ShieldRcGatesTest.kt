package com.snabbit.runner.shared.features.kavach.shield.domain

import com.snabbit.runner.shared.core.config.DefaultRemoteConfigGateway
import com.snabbit.runner.shared.features.kavach.FakeRemoteConfigGateway
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class ShieldRcGatesTest {

    /** Live-RC stub where the listed keys are true; everything else falls back to the caller default. */
    private fun gates(vararg on: String) =
        ShieldRcGates(FakeRemoteConfigGateway().apply { on.forEach { booleans[it] = true } })

    @Test
    fun bothDefaultOff_whenNoFlagsSet() = runTest {
        val g = gates()
        assertFalse(g.monitoringOnlyEnabled())
        assertFalse(g.recordingEnabled())
    }

    @Test
    fun monitoringOnly_whenOnlyItsFlagIsOn() = runTest {
        val g = gates("expert_shield_monitoring_only_enabled")
        assertTrue(g.monitoringOnlyEnabled())
        assertFalse(g.recordingEnabled())   // recording needs its own flag too
    }

    @Test
    fun recordingFlagAlone_isOff_recordingSubsetOfMonitoring() = runTest {
        // recording flag on but monitoring off → recording stays off (recording ⊆ monitoring, Flutter parity)
        assertFalse(gates("expert_shield_recording_enabled").recordingEnabled())
    }

    @Test
    fun recording_onWhenBothFlagsOn() = runTest {
        val g = gates("expert_shield_monitoring_only_enabled", "expert_shield_recording_enabled")
        assertTrue(g.monitoringOnlyEnabled())
        assertTrue(g.recordingEnabled())
    }

    @Test
    fun defaultsGateway_failsClosed() = runTest {
        val g = ShieldRcGates(DefaultRemoteConfigGateway())   // iOS / no RC → defaults (OFF)
        assertFalse(g.monitoringOnlyEnabled())
        assertFalse(g.recordingEnabled())
    }
}
