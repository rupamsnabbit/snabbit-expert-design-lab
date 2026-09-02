package com.snabbit.runner.shared.core.permissions

import com.snabbit.runner.shared.core.permissions.fakes.FakeGrantManager
import com.snabbit.runner.shared.core.permissions.internal.GrantRuntimeDelegate
import dev.brewkits.grant.AppGrant
import dev.brewkits.grant.GrantStatus
import kotlinx.coroutines.flow.toList
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class GrantRuntimeDelegateTest {

    private fun delegate(grant: FakeGrantManager, api: Int = 34) =
        GrantRuntimeDelegate(grant, apiLevel = { api })

    @Test
    fun checkMapsGrantStatus() = runTest {
        val grant = FakeGrantManager().apply { setStatus(AppGrant.CAMERA.identifier, GrantStatus.GRANTED) }
        assertEquals(PermissionStatus.GRANTED, delegate(grant).check(SnabbitPermission.Camera))
    }

    @Test
    fun requestMapsGrantStatusAndRecordsCall() = runTest {
        val grant = FakeGrantManager().apply { setStatus(AppGrant.CAMERA.identifier, GrantStatus.DENIED_ALWAYS) }
        val status = delegate(grant).request(SnabbitPermission.Camera)
        assertEquals(PermissionStatus.DENIED_ALWAYS, status)
        assertTrue(grant.requested.contains(AppGrant.CAMERA.identifier))
    }

    @Test
    fun apiGuardedPermissionBelowMinIsNotAvailableAndNotRequested() = runTest {
        val grant = FakeGrantManager()
        val status = delegate(grant, api = 28).request(SnabbitPermission.LocationBackground)
        assertEquals(PermissionStatus.NOT_AVAILABLE, status)
        assertTrue(grant.requested.isEmpty(), "Grant must not be called for unavailable permission")
    }

    @Test
    fun requestMultipleEmitsInInputOrderWithBatchedResults() = runTest {
        val grant = FakeGrantManager().apply {
            setStatus(AppGrant.LOCATION.identifier, GrantStatus.GRANTED)
            setStatus(AppGrant.CAMERA.identifier, GrantStatus.DENIED)
        }
        val results = delegate(grant).requestMultiple(
            listOf(SnabbitPermission.LocationFine, SnabbitPermission.Camera),
        ).toList()

        assertEquals(
            listOf(
                SnabbitPermission.LocationFine to PermissionStatus.GRANTED,
                SnabbitPermission.Camera to PermissionStatus.DENIED,
            ),
            results,
        )
    }

    @Test
    fun backgroundLocationPartialGrantedReadsAsDenied() = runTest {
        // Foreground-only ("while using") = PARTIAL_GRANTED in Grant. Matching permission_handler's
        // locationAlways, that must read as DENIED so callers trigger the "Allow all the time" upgrade.
        val grant = FakeGrantManager().apply {
            setStatus(AppGrant.LOCATION_ALWAYS.identifier, GrantStatus.PARTIAL_GRANTED)
        }
        assertEquals(
            PermissionStatus.DENIED,
            delegate(grant).check(SnabbitPermission.LocationBackground),
        )
    }

    @Test
    fun partialGrantedStaysGrantedForNonLocationPermissions() = runTest {
        // Photos' limited/"selected" access is genuinely usable, so PARTIAL_GRANTED stays GRANTED.
        val grant = FakeGrantManager().apply {
            setStatus(AppGrant.GALLERY_IMAGES_ONLY.identifier, GrantStatus.PARTIAL_GRANTED)
        }
        assertEquals(
            PermissionStatus.GRANTED,
            delegate(grant).check(SnabbitPermission.Photos),
        )
    }

    @Test
    fun requestMultipleEmitsNotAvailableForUnavailableButBatchesTheRest() = runTest {
        val grant = FakeGrantManager().apply { setStatus(AppGrant.CAMERA.identifier, GrantStatus.GRANTED) }
        val results = delegate(grant, api = 28).requestMultiple(
            listOf(SnabbitPermission.LocationBackground, SnabbitPermission.Camera),
        ).toList()

        assertEquals(SnabbitPermission.LocationBackground to PermissionStatus.NOT_AVAILABLE, results[0])
        assertEquals(SnabbitPermission.Camera to PermissionStatus.GRANTED, results[1])
        // LOCATION_ALWAYS must never reach Grant on API 28
        assertTrue(grant.requested.none { it == AppGrant.LOCATION_ALWAYS.identifier })
    }
}
