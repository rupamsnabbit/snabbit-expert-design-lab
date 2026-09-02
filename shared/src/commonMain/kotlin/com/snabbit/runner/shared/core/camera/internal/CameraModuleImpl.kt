package com.snabbit.runner.shared.core.camera.internal

import com.snabbit.runner.shared.core.camera.CameraConfig
import com.snabbit.runner.shared.core.camera.CameraErrorCode
import com.snabbit.runner.shared.core.camera.CameraModule
import com.snabbit.runner.shared.core.camera.CameraProvider
import com.snabbit.runner.shared.core.camera.CameraResult
import com.snabbit.runner.shared.core.camera.CaptureMode

import com.snabbit.runner.shared.core.AppDispatchers
import com.snabbit.runner.shared.core.Logger
import kotlinx.atomicfu.atomic
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext

/**
 * Internal, library-agnostic orchestration layer.
 *
 * All business logic lives here — reentrancy guard, logging, error
 * mapping, dispatch management. **Zero camera library imports.** The
 * only dependency on the camera library is the injected [CameraProvider].
 *
 * Ported from Flutter's `capture_image_handler.dart`:
 * - Reentrancy guard (`_captureInFlight`) → [mutex] + [_isCapturing]
 * - Logging to MonitoringServiceHelper → [logger]
 * - Error mapping → [CameraErrorCode] constants
 */
internal class CameraModuleImpl(
    private val provider: CameraProvider,
    private val logger: Logger,
    private val dispatchers: AppDispatchers,
) : CameraModule {

    private val tag = "CameraModule"

    /**
     * Reentrancy guard. Uses [AtomicBoolean] for the flag so `cancel()`
     * can read it safely from any thread without acquiring the [Mutex].
     * The [Mutex] protects the check-and-set in `capture()` to prevent
     * two coroutines from both passing the guard.
     */
    private val mutex = Mutex()
    private val _isCapturing = atomic(false)

    override val isCapturing: Boolean get() = _isCapturing.value

    override suspend fun capture(config: CameraConfig): CameraResult {
        // Reentrancy guard — atomic check-and-set via Mutex.
        val acquired = mutex.withLock {
            if (_isCapturing.value) {
                return@withLock false
            }
            _isCapturing.value = true
            true
        }

        if (!acquired) {
            logger.w(tag, "Capture blocked: already in progress")
            return CameraResult.Error(
                code = CameraErrorCode.CAPTURE_IN_PROGRESS,
                message = "A capture is already in progress",
            )
        }

        return try {
            logger.d(tag, "Capture started: lens=${config.lens}, mode=${config.mode}, quality=${config.quality}")

            val result = withContext(dispatchers.main) {
                when (config.mode) {
                    CaptureMode.PHOTO -> provider.capturePhoto(config)
                    CaptureMode.VIDEO -> provider.captureVideo(config)
                }
            }

            when (result) {
                is CameraResult.Photo -> logger.d(
                    tag,
                    "Capture completed: token=${result.token}, size=${result.sizeBytes}",
                )
                is CameraResult.Video -> logger.d(
                    tag,
                    "Video completed: token=${result.token}, size=${result.sizeBytes}, duration=${result.durationMs}ms",
                )
                is CameraResult.Cancelled -> logger.d(tag, "Capture cancelled by user")
                is CameraResult.Error -> logger.w(
                    tag,
                    "Capture error: code=${result.code}, message=${result.message}",
                )
            }

            result
        } catch (e: kotlinx.coroutines.CancellationException) {
            throw e
        } catch (e: Throwable) {
            logger.e(tag, "Capture failed unexpectedly", e)
            CameraResult.Error(
                code = CameraErrorCode.INTERNAL_ERROR,
                message = "Capture failed: ${e.message ?: "unknown error"}",
            )
        } finally {
            _isCapturing.value = false
        }
    }

    override fun cancel() {
        // AtomicBoolean read — safe from any thread without Mutex (C5 fix)
        if (!_isCapturing.value) return
        logger.d(tag, "Cancel requested")
        provider.cancel()
    }
}
