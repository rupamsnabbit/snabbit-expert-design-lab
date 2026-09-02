package com.snabbit.runner.shared.core.camera

/**
 * Seam for publishing an accepted capture to the device's public gallery.
 *
 * The camera module depends only on this interface — never on Android's
 * `MediaStore` (or iOS's `PHPhotoLibrary`) directly. It's invoked by
 * [CameraViewModel] only when [CameraConfig.saveToGallery] is `true`, at the
 * point the capture is accepted (preview Submit, or immediate emit when preview
 * is disabled). Publishing is deliberately separate from the private-temp write
 * the module always does for preview/upload: the temp is never optional, the
 * gallery publish always is.
 *
 * Implementations must be non-blocking-to-delivery: a failure returns `null`
 * (logged internally) rather than throwing, so a gallery-save problem never
 * stops the capture from reaching the host.
 */
interface MediaPersister {
    /**
     * Publish [media] to the device gallery. Returns the resulting content
     * URI/id string on success, or `null` when unsupported (e.g. pre-Android-10
     * scoped-storage) or on failure. Must not delete [media]'s `filePath` — the
     * host still needs it for upload; `CaptureRegistry`'s TTL reclaims the temp.
     */
    suspend fun saveToGallery(media: CapturedMedia): String?
}

/**
 * Default seam impl that publishes nothing. Used as the back-compat/test default
 * and on platforms without a gallery integration (iOS today). Production Android
 * hosts inject the `GalleryMediaPersister` that wraps `GallerySaver`.
 */
object NoOpMediaPersister : MediaPersister {
    override suspend fun saveToGallery(media: CapturedMedia): String? = null
}
