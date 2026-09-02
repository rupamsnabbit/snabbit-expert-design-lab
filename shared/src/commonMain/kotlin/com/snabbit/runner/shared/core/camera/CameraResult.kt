package com.snabbit.runner.shared.core.camera

/**
 * A successfully captured, previewable artifact (the success subset of
 * [CameraResult]). Both [CameraResult.Photo] and [CameraResult.Video]
 * implement this so the preview layer can handle either without asserting
 * the concrete type. Extensible to future capture kinds (multi-shot,
 * document scan) without touching the preview API.
 */
sealed interface CapturedMedia {
    val filePath: String
    val token: String
    val sizeBytes: Long
}

/**
 * Outcome of a [CameraModule.capture] call.
 *
 * Sealed so callers can exhaustively `when`-branch. [Photo] and [Video]
 * carry the file path and a registry token the WebView can fetch via
 * the asset-loader URL, and implement [CapturedMedia] for the preview
 * layer. [Cancelled] and [Error] are terminal states (not previewable).
 */
sealed class CameraResult {

    /** A still image was captured successfully. */
    data class Photo(
        override val filePath: String,
        override val token: String,
        override val sizeBytes: Long,
    ) : CameraResult(), CapturedMedia

    /** A video was recorded successfully. */
    data class Video(
        override val filePath: String,
        override val token: String,
        override val sizeBytes: Long,
        val durationMs: Long,
    ) : CameraResult(), CapturedMedia

    /** The user dismissed the camera without capturing. */
    data object Cancelled : CameraResult()

    /**
     * The capture failed. [code] is a machine-readable constant from
     * [CameraErrorCode]; [message] is a human-readable description for
     * logging (not shown to the user).
     */
    data class Error(
        val code: String,
        val message: String,
    ) : CameraResult()
}

/**
 * Machine-readable error codes returned in [CameraResult.Error.code].
 * Mirrors the bifrost error codes from the Flutter implementation.
 */
object CameraErrorCode {
    const val CAPTURE_IN_PROGRESS = "CAPTURE_IN_PROGRESS"
    const val PERMISSION_DENIED = "PERMISSION_DENIED"
    const val USER_CANCELLED = "USER_CANCELLED"
    const val INTERNAL_ERROR = "INTERNAL_ERROR"
    const val FILE_TOO_LARGE = "FILE_TOO_LARGE"
    const val CAMERA_NOT_READY = "CAMERA_NOT_READY"

    /** Capture couldn't be written to disk (storage full / unwritable). */
    const val STORAGE_FULL = "STORAGE_FULL"
}

/**
 * The size cap (bytes) for this media kind — 10 MB photo, 50 MB video.
 * Sourced from [CaptureRegistry].
 */
fun CapturedMedia.sizeCapBytes(): Long = when (this) {
    is CameraResult.Photo -> CaptureRegistry.MAX_PHOTO_SIZE_BYTES
    is CameraResult.Video -> CaptureRegistry.MAX_VIDEO_SIZE_BYTES
}

/**
 * Whether this captured media exceeds its size cap. Over-cap media is
 * blocked from Submit on the preview (the WebView asset handler would
 * 404 it downstream anyway). Public so custom preview presenters can
 * enforce the same rule.
 */
fun CapturedMedia.exceedsSizeCap(): Boolean = sizeBytes > sizeCapBytes()
