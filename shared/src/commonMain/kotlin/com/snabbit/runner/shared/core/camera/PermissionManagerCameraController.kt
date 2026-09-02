package com.snabbit.runner.shared.core.camera

import com.snabbit.runner.shared.core.permissions.PermissionManager
import com.snabbit.runner.shared.core.permissions.PermissionStatus
import com.snabbit.runner.shared.core.permissions.SnabbitPermission

/**
 * Adapts the shared [PermissionManager] to the camera module's
 * [CameraPermissionController] seam — this is the "dedicated KMP permissions
 * module" the seam's own doc anticipated. Nothing in [CameraViewModel] or the
 * capture UI changes; the host just injects this instead of a platform-specific
 * controller, so camera + microphone permissions go through the same Grant-backed
 * pipeline the rest of the app uses (and iOS comes for free once its
 * `PermissionManager` actual is wired).
 *
 * **Host contract:** [PermissionManager.request] needs an attached Activity, so
 * the host must call `ActivityAttachable.attachActivity(activity)` in `onCreate`
 * and `detach()` in `onDestroy` (the app already does this for its other
 * permissions). With none attached, requests degrade to [PermissionStatus.DENIED]
 * — never a crash — which maps to [CameraPermissionStatus.DENIED] here.
 */
class PermissionManagerCameraController(
    private val permissions: PermissionManager,
) : CameraPermissionController {

    override suspend fun status(): CameraPermissionStatus =
        permissions.check(SnabbitPermission.Camera).toCameraPermissionStatus()

    override suspend fun request(): CameraPermissionStatus =
        permissions.request(SnabbitPermission.Camera).toCameraPermissionStatus()

    override suspend fun requestMicrophone(): CameraPermissionStatus =
        permissions.request(SnabbitPermission.Microphone).toCameraPermissionStatus()

    override fun openAppSettings() {
        permissions.openSettings()
    }
}

/**
 * Collapses the shared module's 4-value [PermissionStatus] onto the camera's
 * 3-value [CameraPermissionStatus]. [PermissionStatus.NOT_AVAILABLE] (the
 * permission doesn't exist on this device/OS level — e.g. a device with no
 * microphone) maps to [CameraPermissionStatus.PERMANENTLY_DENIED]: there is no
 * dialog that can grant it, so the capture UI routes to the "open settings"
 * path rather than looping on a re-request that can never succeed.
 */
private fun PermissionStatus.toCameraPermissionStatus(): CameraPermissionStatus = when (this) {
    PermissionStatus.GRANTED -> CameraPermissionStatus.GRANTED
    PermissionStatus.DENIED -> CameraPermissionStatus.DENIED
    PermissionStatus.DENIED_ALWAYS,
    PermissionStatus.NOT_AVAILABLE -> CameraPermissionStatus.PERMANENTLY_DENIED
}
