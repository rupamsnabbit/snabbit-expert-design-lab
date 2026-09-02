package com.snabbit.runner.shared.core.camera

import android.content.Context
import com.snabbit.runner.shared.core.Logger

/**
 * Android [MediaPersister]: publishes an accepted capture to the public gallery
 * via [GallerySaver] (MediaStore — `Pictures/`/`Movies/SnabbitCaptures`).
 *
 * Branches on the media kind and uses the capture token as the display name
 * (unique per capture). `deleteSourceOnSuccess = false` — the private temp is
 * **kept** so the emitted `filePath` stays valid for the host's upload;
 * `CaptureRegistry`'s TTL reclaims it later. Returns `null` on pre-Android-10
 * devices (no scoped-storage MediaStore write) or on failure — [GallerySaver]
 * logs the reason and never throws, so delivery is never blocked.
 *
 * Pass the **application** context to avoid holding an Activity.
 */
class GalleryMediaPersister(
    private val context: Context,
    private val logger: Logger,
) : MediaPersister {

    override suspend fun saveToGallery(media: CapturedMedia): String? = when (media) {
        is CameraResult.Photo -> GallerySaver.savePhoto(
            context = context,
            filePath = media.filePath,
            displayName = media.token,
            logger = logger,
            deleteSourceOnSuccess = false,
        )
        is CameraResult.Video -> GallerySaver.saveVideo(
            context = context,
            filePath = media.filePath,
            displayName = media.token,
            logger = logger,
            deleteSourceOnSuccess = false,
        )
    }
}
