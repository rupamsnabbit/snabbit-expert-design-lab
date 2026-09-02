package com.snabbit.runner.shared.core.camera.fakes

import com.snabbit.runner.shared.core.camera.CameraConfig
import com.snabbit.runner.shared.core.camera.CameraModule
import com.snabbit.runner.shared.core.camera.CameraResult

/**
 * Test double for [CameraModule]. The [CameraViewModel] only calls
 * [cancel] directly (capture is driven by the composable in production),
 * so this fake just records interactions.
 */
internal class FakeCameraModule : CameraModule {
    var cancelCount = 0
    override val isCapturing: Boolean = false

    override suspend fun capture(config: CameraConfig): CameraResult =
        CameraResult.Cancelled

    override fun cancel() {
        cancelCount++
    }
}
