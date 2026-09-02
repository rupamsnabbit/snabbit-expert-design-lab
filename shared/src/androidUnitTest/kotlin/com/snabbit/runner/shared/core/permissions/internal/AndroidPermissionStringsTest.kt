package com.snabbit.runner.shared.core.permissions.internal

import android.Manifest
import android.os.Build
import com.snabbit.runner.shared.core.permissions.SnabbitPermission
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Verifies [primaryAndroidPermission] resolves to the permission Grant actually requests at each
 * API level. Regression guard for the bug where the static mapping checked `READ_MEDIA_IMAGES` on
 * API <= 32 (where Grant uses `READ_EXTERNAL_STORAGE`), mislabeling re-askable denials as
 * DENIED_ALWAYS. Robolectric's @Config(sdk = ...) drives Build.VERSION.SDK_INT.
 */
@RunWith(RobolectricTestRunner::class)
class AndroidPermissionStringsTest {

    @Test
    @Config(sdk = [Build.VERSION_CODES.TIRAMISU]) // API 33
    fun `media and notification use API 33 permissions on api 33+`() {
        assertEquals("android.permission.READ_MEDIA_IMAGES", SnabbitPermission.Photos.primaryAndroidPermission())
        assertEquals("android.permission.READ_MEDIA_IMAGES", SnabbitPermission.Storage.primaryAndroidPermission())
        assertEquals("android.permission.POST_NOTIFICATIONS", SnabbitPermission.Notifications.primaryAndroidPermission())
    }

    @Test
    @Config(sdk = [Build.VERSION_CODES.R]) // API 30
    fun `media falls back to external storage and notification is null below api 33`() {
        assertEquals(Manifest.permission.READ_EXTERNAL_STORAGE, SnabbitPermission.Photos.primaryAndroidPermission())
        assertEquals(Manifest.permission.READ_EXTERNAL_STORAGE, SnabbitPermission.Storage.primaryAndroidPermission())
        assertNull(SnabbitPermission.Notifications.primaryAndroidPermission())
    }

    @Test
    @Config(sdk = [Build.VERSION_CODES.TIRAMISU])
    fun `api-independent runtime permissions map to their fixed strings`() {
        assertEquals(Manifest.permission.ACCESS_FINE_LOCATION, SnabbitPermission.LocationFine.primaryAndroidPermission())
        assertEquals(Manifest.permission.ACCESS_COARSE_LOCATION, SnabbitPermission.LocationCoarse.primaryAndroidPermission())
        assertEquals(Manifest.permission.ACCESS_BACKGROUND_LOCATION, SnabbitPermission.LocationBackground.primaryAndroidPermission())
        assertEquals(Manifest.permission.CAMERA, SnabbitPermission.Camera.primaryAndroidPermission())
        assertEquals(Manifest.permission.RECORD_AUDIO, SnabbitPermission.Microphone.primaryAndroidPermission())
        assertEquals(Manifest.permission.READ_CONTACTS, SnabbitPermission.Contacts.primaryAndroidPermission())
    }

    @Test
    @Config(sdk = [Build.VERSION_CODES.TIRAMISU])
    fun `strict, informational and special-access permissions have no runtime string`() {
        assertNull(SnabbitPermission.ExactAlarm.primaryAndroidPermission())
        assertNull(SnabbitPermission.Overlay.primaryAndroidPermission())
        assertNull(SnabbitPermission.BatteryOptimization.primaryAndroidPermission())
        assertNull(SnabbitPermission.AccessibilityService.primaryAndroidPermission())
        assertNull(SnabbitPermission.AdminPolicy.primaryAndroidPermission())
    }
}
