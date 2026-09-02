package com.snabbit.runner.shared.core.camera.fakes

import com.snabbit.runner.shared.core.camera.CameraConfig
import com.snabbit.runner.shared.core.camera.CameraProvider
import com.snabbit.runner.shared.core.camera.CameraResult
import kotlinx.coroutines.CompletableDeferred

/**
 * Test double for [CameraProvider].
 *
 * Allows tests to control the outcome of capture calls without
 * initializing any camera library or Android/iOS context.
 * Follows the Hello module's `FakeLogger` pattern.
 */
internal class FakeCameraProvider : CameraProvider {

    /** The result that the next [capturePhoto] or [captureVideo] will return. */
    var nextResult: CameraResult = CameraResult.Cancelled

    /** How many times [capturePhoto] has been called. */
    var photoCaptureCount = 0

    /** How many times [captureVideo] has been called. */
    var videoCaptureCount = 0

    /** How many times [cancel] has been called. */
    var cancelCount = 0

    /** The last config passed to [capturePhoto] or [captureVideo]. */
    var lastConfig: CameraConfig? = null

    /** When set, capture suspends on it before returning — lets a test hold a
     *  capture in flight to exercise the reentrancy guard. Null = return immediately. */
    var captureGate: CompletableDeferred<Unit>? = null

    private var _isCapturing = false

    override val isCapturing: Boolean get() = _isCapturing

    override suspend fun capturePhoto(config: CameraConfig): CameraResult {
        photoCaptureCount++
        lastConfig = config
        _isCapturing = true
        try {
            captureGate?.await()
            return nextResult
        } finally {
            _isCapturing = false
        }
    }

    override suspend fun captureVideo(config: CameraConfig): CameraResult {
        videoCaptureCount++
        lastConfig = config
        _isCapturing = true
        try {
            captureGate?.await()
            return nextResult
        } finally {
            _isCapturing = false
        }
    }

    override fun cancel() {
        cancelCount++
        _isCapturing = false
    }
}
