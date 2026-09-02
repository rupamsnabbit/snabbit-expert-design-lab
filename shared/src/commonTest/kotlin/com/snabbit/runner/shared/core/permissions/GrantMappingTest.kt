package com.snabbit.runner.shared.core.permissions

import com.snabbit.runner.shared.core.permissions.internal.minApiLevel
import com.snabbit.runner.shared.core.permissions.internal.toGrantOrNull
import com.snabbit.runner.shared.core.permissions.internal.toPermissionStatus
import dev.brewkits.grant.AppGrant
import dev.brewkits.grant.GrantStatus
import dev.brewkits.grant.RawPermission
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

class GrantMappingTest {

    @Test
    fun runtimePermissionsMapToExpectedGrant() {
        assertEquals(AppGrant.LOCATION, SnabbitPermission.LocationFine.toGrantOrNull())
        assertEquals(AppGrant.LOCATION_ALWAYS, SnabbitPermission.LocationBackground.toGrantOrNull())
        assertEquals(AppGrant.CAMERA, SnabbitPermission.Camera.toGrantOrNull())
        assertEquals(AppGrant.MICROPHONE, SnabbitPermission.Microphone.toGrantOrNull())
        assertEquals(AppGrant.READ_CONTACTS, SnabbitPermission.Contacts.toGrantOrNull())
        assertEquals(AppGrant.NOTIFICATION, SnabbitPermission.Notifications.toGrantOrNull())
        assertEquals(AppGrant.SCHEDULE_EXACT_ALARM, SnabbitPermission.ExactAlarm.toGrantOrNull())
        assertEquals(AppGrant.GALLERY_IMAGES_ONLY, SnabbitPermission.Photos.toGrantOrNull())
        assertEquals(AppGrant.STORAGE, SnabbitPermission.Storage.toGrantOrNull())
    }

    @Test
    fun coarseLocationMapsToRawCoarsePermission() {
        val grant = SnabbitPermission.LocationCoarse.toGrantOrNull()
        assertTrue(grant is RawPermission)
        assertTrue(grant.androidPermissions.contains("android.permission.ACCESS_COARSE_LOCATION"))
    }

    @Test
    fun strictAndInfoPermissionsAreNotRuntimeGrants() {
        assertNull(SnabbitPermission.Overlay.toGrantOrNull())
        assertNull(SnabbitPermission.BatteryOptimization.toGrantOrNull())
        assertNull(SnabbitPermission.AccessibilityService.toGrantOrNull())
        assertNull(SnabbitPermission.AdminPolicy.toGrantOrNull())
    }

    @Test
    fun apiGuardedPermissionsRequireApi29() {
        assertEquals(29, SnabbitPermission.LocationBackground.minApiLevel())
        assertEquals(1, SnabbitPermission.Camera.minApiLevel())
        assertEquals(1, SnabbitPermission.LocationFine.minApiLevel())
    }

    @Test
    fun grantStatusCollapsesToFourValues() {
        assertEquals(PermissionStatus.GRANTED, GrantStatus.GRANTED.toPermissionStatus())
        assertEquals(PermissionStatus.GRANTED, GrantStatus.PARTIAL_GRANTED.toPermissionStatus())
        assertEquals(PermissionStatus.DENIED, GrantStatus.DENIED.toPermissionStatus())
        assertEquals(PermissionStatus.DENIED_ALWAYS, GrantStatus.DENIED_ALWAYS.toPermissionStatus())
        assertEquals(PermissionStatus.DENIED, GrantStatus.NOT_DETERMINED.toPermissionStatus())
        assertEquals(PermissionStatus.DENIED, GrantStatus.BUSY.toPermissionStatus())
    }
}
