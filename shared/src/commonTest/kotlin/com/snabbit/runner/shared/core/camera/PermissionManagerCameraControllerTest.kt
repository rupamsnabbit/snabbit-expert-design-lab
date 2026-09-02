package com.snabbit.runner.shared.core.camera

import com.snabbit.runner.shared.core.permissions.PermissionStatus
import com.snabbit.runner.shared.core.permissions.SnabbitPermission
import com.snabbit.runner.shared.core.permissions.fakes.FakePermissionManager
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals

/**
 * Verifies [PermissionManagerCameraController] adapts the shared
 * [com.snabbit.runner.shared.core.permissions.PermissionManager] to the camera
 * seam: the 4-value [PermissionStatus] collapses correctly onto the 3-value
 * [CameraPermissionStatus], and each call targets the right permission.
 */
class PermissionManagerCameraControllerTest {

    @Test
    fun `maps every PermissionStatus onto the camera status`() = runTest {
        val cases = mapOf(
            PermissionStatus.GRANTED to CameraPermissionStatus.GRANTED,
            PermissionStatus.DENIED to CameraPermissionStatus.DENIED,
            PermissionStatus.DENIED_ALWAYS to CameraPermissionStatus.PERMANENTLY_DENIED,
            PermissionStatus.NOT_AVAILABLE to CameraPermissionStatus.PERMANENTLY_DENIED,
        )
        for ((source, expected) in cases) {
            val controller = PermissionManagerCameraController(
                FakePermissionManager(defaultStatus = source),
            )
            assertEquals(expected, controller.status(), "status() for $source")
            assertEquals(expected, controller.request(), "request() for $source")
            assertEquals(expected, controller.requestMicrophone(), "requestMicrophone() for $source")
        }
    }

    @Test
    fun `request targets Camera and requestMicrophone targets Microphone`() = runTest {
        val controller = PermissionManagerCameraController(
            FakePermissionManager(
                statuses = mutableMapOf(
                    SnabbitPermission.Camera to PermissionStatus.GRANTED,
                    SnabbitPermission.Microphone to PermissionStatus.DENIED_ALWAYS,
                ),
            ),
        )

        assertEquals(CameraPermissionStatus.GRANTED, controller.status())
        assertEquals(CameraPermissionStatus.GRANTED, controller.request())
        assertEquals(CameraPermissionStatus.PERMANENTLY_DENIED, controller.requestMicrophone())
    }

    @Test
    fun `openAppSettings delegates to the permission manager`() {
        // FakePermissionManager.openSettings() is a no-op; exercise the delegate path.
        PermissionManagerCameraController(FakePermissionManager()).openAppSettings()
    }
}
