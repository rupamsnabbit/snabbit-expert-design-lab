package com.snabbit.runner.shared.core.camera.fakes

import com.snabbit.runner.shared.core.camera.CameraPermissionController
import com.snabbit.runner.shared.core.camera.CameraPermissionStatus

/** Scriptable test double for [CameraPermissionController]. */
internal class FakeCameraPermissionController(
    var statusResult: CameraPermissionStatus = CameraPermissionStatus.GRANTED,
    var requestResult: CameraPermissionStatus = CameraPermissionStatus.GRANTED,
    var microphoneResult: CameraPermissionStatus = CameraPermissionStatus.GRANTED,
) : CameraPermissionController {
    var statusCalls = 0
    var requestCalls = 0
    var microphoneRequestCalls = 0
    var openSettingsCalls = 0

    override suspend fun status(): CameraPermissionStatus {
        statusCalls++
        return statusResult
    }

    override suspend fun request(): CameraPermissionStatus {
        requestCalls++
        return requestResult
    }

    override suspend fun requestMicrophone(): CameraPermissionStatus {
        microphoneRequestCalls++
        return microphoneResult
    }

    override fun openAppSettings() {
        openSettingsCalls++
    }
}
