package com.snabbit.runner.shared.core.camera

/**
 * Configuration for a camera capture session.
 *
 * Passed from the caller (bifrost RPC payload or native Compose screen) to
 * [CameraModule.capture]. Every field has a sensible default so the caller
 * can omit fields they don't care about.
 */
data class CameraConfig(
    val lens: CameraLens = CameraLens.FRONT,
    val mode: CaptureMode = CaptureMode.PHOTO,
    val quality: CaptureQuality = CaptureQuality.HIGH,
    val maxVideoDurationMs: Long = 30_000L,
    /**
     * Record audio with [CaptureMode.VIDEO]. Default `false` (silent) so the
     * mic permission isn't needed unless a caller opts in. When `true`, the
     * module requests `RECORD_AUDIO` at record start; if it isn't granted the
     * clip records silently — the capture is never blocked. No effect on PHOTO.
     */
    val enableAudio: Boolean = false,
    /**
     * Publish the accepted capture to the device's **public** gallery
     * (MediaStore — `Pictures/`/`Movies/SnabbitCaptures`) via the injected
     * `MediaPersister`. Default `false`: the capture stays app-private (its
     * `filePath` is still fully usable for preview and upload), which is the
     * safe default for verification selfies — the public gallery is readable by
     * any app holding the media-read permission. Set `true` only when publishing
     * to the shared gallery is an intentional, product-approved requirement.
     * Preview works either way; a private temp is always written and reclaimed
     * by `CaptureRegistry`'s TTL.
     */
    val saveToGallery: Boolean = false,
    /**
     * Which composition guide to overlay on the live **photo**-capture preview:
     * [CameraOverlay.FACE] the head+shoulders selfie silhouette (front camera
     * only), [CameraOverlay.OVAL] a dashed portrait oval (any lens), or
     * [CameraOverlay.NONE]. No effect on [CaptureMode.VIDEO]. Default keeps the
     * existing front-selfie guide.
     */
    val overlay: CameraOverlay = CameraOverlay.FACE,
)

/** Which physical camera to open. */
enum class CameraLens { FRONT, BACK }

/** Whether to capture a still photo or record video. */
enum class CaptureMode { PHOTO, VIDEO }

/**
 * Capture quality hint. The [CameraProvider] maps this to platform-specific
 * resolution/compression settings. If the requested quality is unavailable
 * the provider falls back to the next lower tier (HIGH → MEDIUM → LOW).
 */
enum class CaptureQuality { LOW, MEDIUM, HIGH }

/**
 * Composition guide drawn over the live photo-capture preview (selectable by the
 * caller). No effect on video capture.
 * - [NONE] no overlay.
 * - [FACE] head+shoulders selfie silhouette — shown on the front camera.
 * - [OVAL] dashed portrait oval — shown on any lens.
 */
enum class CameraOverlay { NONE, FACE, OVAL }
