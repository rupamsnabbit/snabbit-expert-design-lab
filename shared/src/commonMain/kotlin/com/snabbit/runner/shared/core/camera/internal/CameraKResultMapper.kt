package com.snabbit.runner.shared.core.camera.internal

import com.snabbit.runner.shared.core.camera.CameraErrorCode
import com.snabbit.runner.shared.core.camera.CameraResult
import com.snabbit.runner.shared.core.camera.CaptureRegistry

import com.kashif.cameraK.result.ImageCaptureResult
import com.kashif.cameraK.state.CameraKEvent
import com.kashif.cameraK.video.VideoCaptureResult
import kotlinx.coroutines.CancellationException

/**
 * Maps a CameraK capture event to the library-agnostic [CameraResult].
 *
 * Extracted from [CameraScreen]'s event collector so that:
 * 1. the CameraK→domain mapping is **unit-testable** (no composable needed), and
 * 2. the CameraK coupling lives in one named, swappable place rather than
 *    buried inside a `LaunchedEffect`.
 *
 * Returns `null` for events that aren't capture outcomes (recording
 * lifecycle, QR, etc.) so the collector can ignore them.
 *
 * File I/O and token generation are performed through the injected [fileOps]
 * seam ([PlatformFileOps]); the seam threads the (potentially multi-MB) byte
 * write / decode / compress off the main thread on [com.snabbit.runner.shared.core.AppDispatchers],
 * so this no longer hardcodes `Dispatchers.Default`. A `writeTempFile` failure
 * (storage full) maps to [CameraErrorCode.STORAGE_FULL] rather than propagating.
 */
internal suspend fun CameraKEvent.toCameraResultOrNull(fileOps: PlatformFileOps): CameraResult? =
    when (val event = this) {
        is CameraKEvent.ImageCaptured -> event.result.toCameraResult(fileOps)
        is CameraKEvent.CaptureFailed -> CameraResult.Error(
            code = CameraErrorCode.INTERNAL_ERROR,
            message = event.exception.message ?: "Capture failed",
        )
        is CameraKEvent.RecordingStopped -> event.result.toVideoResult(fileOps)
        is CameraKEvent.RecordingMaxDurationReached -> CameraResult.Video(
            filePath = event.filePath,
            token = CaptureRegistry.generateToken(),
            sizeBytes = fileOps.fileSize(event.filePath),
            durationMs = event.durationMs,
        )
        is CameraKEvent.RecordingFailed -> CameraResult.Error(
            code = CameraErrorCode.INTERNAL_ERROR,
            message = event.exception.message ?: "Recording failed",
        )
        else -> null
    }

/** Maps CameraK's video recording result to the domain [CameraResult]. */
private fun VideoCaptureResult.toVideoResult(fileOps: PlatformFileOps): CameraResult = when (this) {
    is VideoCaptureResult.Success -> CameraResult.Video(
        filePath = filePath,
        token = CaptureRegistry.generateToken(),
        sizeBytes = fileOps.fileSize(filePath),
        durationMs = durationMs,
    )
    is VideoCaptureResult.Error -> CameraResult.Error(
        code = CameraErrorCode.INTERNAL_ERROR,
        message = exception.message ?: "Recording failed",
    )
}

private suspend fun ImageCaptureResult.toCameraResult(fileOps: PlatformFileOps): CameraResult = when (this) {
    is ImageCaptureResult.SuccessWithFile -> {
        val token = CaptureRegistry.generateToken()
        // CameraK saved the full-res JPEG to app-private storage (directory =
        // DOCUMENTS — not the public gallery). If it's oversize, the deliverable
        // (uploaded / served to the WebView, which 404s files over the cap) is a
        // capped COPY; the original is a temp reclaimed by CaptureRegistry's TTL.
        // No-op (same path, no decode) when within cap. Public-gallery publish, if
        // opted in, is the MediaPersister's job — not this path.
        val finalPath = fileOps.compressImageToFit(filePath, CaptureRegistry.MAX_PHOTO_SIZE_BYTES)
        CameraResult.Photo(
            filePath = finalPath,
            token = token,
            sizeBytes = fileOps.fileSize(finalPath),
        )
    }
    is ImageCaptureResult.Success -> {
        val token = CaptureRegistry.generateToken()
        // writeTempFile can fail if storage is full / unwritable — surface a
        // retry-able error instead of crashing the event collector. The seam
        // threads the byte write + compress off the main thread itself.
        try {
            val rawPath = fileOps.writeTempFile(
                bytes = byteArray,
                prefix = "capture_${token}_",
                suffix = ".jpg",
            )
            val finalPath = fileOps.compressImageToFit(rawPath, CaptureRegistry.MAX_PHOTO_SIZE_BYTES)
            // Reclaim the pre-compression temp if a smaller copy was written.
            if (finalPath != rawPath) fileOps.deleteFile(rawPath)
            CameraResult.Photo(
                filePath = finalPath,
                token = token,
                sizeBytes = fileOps.fileSize(finalPath),
            )
        } catch (e: CancellationException) {
            throw e
        } catch (e: Throwable) {
            CameraResult.Error(
                code = CameraErrorCode.STORAGE_FULL,
                message = "Couldn't save the photo — storage may be full.",
            )
        }
    }
    is ImageCaptureResult.Error -> CameraResult.Error(
        code = CameraErrorCode.INTERNAL_ERROR,
        message = exception.message ?: "Capture failed",
    )
}
