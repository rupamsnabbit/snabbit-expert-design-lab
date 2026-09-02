package com.snabbit.runner.shared.core.camera.internal

import com.snabbit.runner.shared.core.camera.CameraConfig
import com.snabbit.runner.shared.core.camera.CameraErrorCode
import com.snabbit.runner.shared.core.camera.CameraProvider
import com.snabbit.runner.shared.core.camera.CameraResult

import com.snabbit.runner.shared.core.Logger

/**
 * CameraK-specific [CameraProvider] implementation for iOS.
 *
 * Uses AVFoundation under the hood via CameraK's iOS expect/actual layer.
 *
 * TODO: Implement when iOS launch is on the roadmap. Currently a
 * stub that returns [CameraErrorCode.CAMERA_NOT_READY] for all operations,
 * ensuring commonMain purity (compiles for iOS without platform APIs).
 */
internal class CameraKProvider(
    private val logger: Logger,
) : CameraProvider {

    private val tag = "CameraKProvider.iOS"

    override val isCapturing: Boolean get() = false

    override suspend fun capturePhoto(config: CameraConfig): CameraResult {
        logger.d(tag, "capturePhoto called (iOS stub)")
        return CameraResult.Error(
            code = CameraErrorCode.CAMERA_NOT_READY,
            message = "iOS CameraK integration not yet implemented",
        )
    }

    override suspend fun captureVideo(config: CameraConfig): CameraResult {
        logger.d(tag, "captureVideo called (iOS stub)")
        return CameraResult.Error(
            code = CameraErrorCode.CAMERA_NOT_READY,
            message = "iOS CameraK video integration not yet implemented",
        )
    }

    override fun cancel() {
        logger.d(tag, "cancel requested (iOS stub — no-op)")
    }
}
