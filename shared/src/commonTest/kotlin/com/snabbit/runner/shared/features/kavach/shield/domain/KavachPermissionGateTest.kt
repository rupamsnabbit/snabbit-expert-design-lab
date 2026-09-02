package com.snabbit.runner.shared.features.kavach.shield.domain

import com.snabbit.runner.shared.core.permissions.PermissionStatus
import com.snabbit.runner.shared.core.permissions.SnabbitPermission
import com.snabbit.runner.shared.core.permissions.fakes.FakePermissionManager
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals

class KavachPermissionGateTest {

    private fun gate(vararg statuses: Pair<SnabbitPermission, PermissionStatus>) =
        KavachPermissionGate(FakePermissionManager(statuses = statuses.toMap().toMutableMap(), defaultStatus = PermissionStatus.DENIED))

    @Test
    fun micOnly_granted() = runTest {
        val g = gate(SnabbitPermission.Microphone to PermissionStatus.GRANTED)
        assertEquals(KavachPermissionResult.Granted, g.ensure(KavachPermissionContext.MicOnly))
    }

    @Test
    fun micOnly_denied() = runTest {
        val g = gate(SnabbitPermission.Microphone to PermissionStatus.DENIED)
        assertEquals(KavachPermissionResult.Denied, g.ensure(KavachPermissionContext.MicOnly))
    }

    @Test
    fun micOnly_permanentlyDenied_needsSettings() = runTest {
        val g = gate(SnabbitPermission.Microphone to PermissionStatus.DENIED_ALWAYS)
        assertEquals(KavachPermissionResult.NeedsSettings, g.ensure(KavachPermissionContext.MicOnly))
    }

    @Test
    fun micAndLocation_allGranted() = runTest {
        val g = gate(
            SnabbitPermission.Microphone to PermissionStatus.GRANTED,
            SnabbitPermission.LocationFine to PermissionStatus.GRANTED,
            SnabbitPermission.LocationBackground to PermissionStatus.GRANTED,
        )
        assertEquals(KavachPermissionResult.Granted, g.ensure(KavachPermissionContext.MicAndLocation))
    }

    @Test
    fun micAndLocation_backgroundDenied_isDenied() = runTest {
        val g = gate(
            SnabbitPermission.Microphone to PermissionStatus.GRANTED,
            SnabbitPermission.LocationFine to PermissionStatus.GRANTED,
            SnabbitPermission.LocationBackground to PermissionStatus.DENIED,
        )
        assertEquals(KavachPermissionResult.Denied, g.ensure(KavachPermissionContext.MicAndLocation))
    }
}
