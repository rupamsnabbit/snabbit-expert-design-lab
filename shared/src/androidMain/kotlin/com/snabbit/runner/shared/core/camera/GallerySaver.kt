package com.snabbit.runner.shared.core.camera

import android.content.ContentValues
import android.content.Context
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import com.snabbit.runner.shared.core.Logger
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.io.IOException

/**
 * A single request to publish one captured file to the public [MediaStore].
 * Groups the per-capture parameters so [GallerySaver]'s writer takes one request
 * object instead of a long positional parameter list.
 */
internal data class MediaStoreRequest(
    val filePath: String,
    /** Display name including the extension, e.g. `"<token>.jpg"`. */
    val displayName: String,
    val mimeType: String,
    /** MediaStore relative path, e.g. `"Pictures/SnabbitCaptures"`. */
    val relativePath: String,
    /** The MediaStore collection URI to insert into. */
    val collection: Uri,
    /**
     * When true, deletes [filePath] after a successful copy (move semantics) —
     * use for the preview path's private temp so it doesn't linger after Submit.
     */
    val deleteSourceOnSuccess: Boolean = false,
)

/**
 * Saves captured photos/videos to the device **public** gallery via
 * [MediaStore]. Photos appear in `Pictures/SnabbitCaptures`, videos in
 * `Movies/SnabbitCaptures`.
 *
 * **Requires API 29+ (Scoped Storage).** No `WRITE_EXTERNAL_STORAGE` is
 * declared, and a pre-Q public-gallery write would need it — so on API 26–28
 * this is a no-op (returns `null`) and the capture simply stays private. That
 * private `filePath` is still fully usable for upload / WebView serving (the
 * production path); publishing to the gallery is an optional extra.
 *
 * ⚠️ **PRIVACY — read before calling.** The public gallery is readable by
 * any app holding `READ_MEDIA_IMAGES` / `READ_MEDIA_VIDEO`. A verification
 * selfie (shift login, go-live) published here is visible to every such app.
 * The camera module deliberately does **NOT** call this on the preview path —
 * captures stay in app-private storage and **the host decides** whether to
 * publish. Only call this when publishing to the shared gallery is an
 * intentional, product-approved requirement; otherwise keep the file private
 * (its `filePath` is already usable for upload / WebView serving).
 *
 * **Sole public-gallery route.** CameraK is configured to write its own captures to
 * app-private storage (`Directory.DOCUMENTS`), so captures do NOT reach the device
 * gallery on their own. This saver — invoked via a wired [GalleryMediaPersister] only
 * when `CameraConfig.saveToGallery` is `true` — is the one intentional path to the
 * public gallery. Production leaves `saveToGallery` `false` (fail-closed for PII).
 *
 * Standalone utility — does NOT depend on CameraK's `ImageSaverPlugin`;
 * works with file paths, matching how the capture flow returns results.
 */
object GallerySaver {

    private const val TAG = "GallerySaver"
    private const val FOLDER_NAME = "SnabbitCaptures"

    /**
     * Copies the captured photo file into [MediaStore.Images] so it
     * appears in the device gallery.
     *
     * @param deleteSourceOnSuccess when true, deletes [filePath] after a
     *   successful copy (move semantics) — use for the preview path's private
     *   temp so it doesn't linger after Submit.
     * @return The content URI string if successful, null on failure.
     */
    suspend fun savePhoto(
        context: Context,
        filePath: String,
        displayName: String,
        logger: Logger,
        deleteSourceOnSuccess: Boolean = false,
    ): String? = withContext(Dispatchers.IO) {
        saveToMediaStore(
            context = context,
            request = MediaStoreRequest(
                filePath = filePath,
                displayName = "$displayName.jpg",
                mimeType = "image/jpeg",
                relativePath = "Pictures/$FOLDER_NAME",
                collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
                } else {
                    MediaStore.Images.Media.EXTERNAL_CONTENT_URI
                },
                deleteSourceOnSuccess = deleteSourceOnSuccess,
            ),
            logger = logger,
        )
    }

    /**
     * Copies the captured video file into [MediaStore.Video] so it
     * appears in the device gallery.
     *
     * @param deleteSourceOnSuccess see [savePhoto].
     * @return The content URI string if successful, null on failure.
     */
    suspend fun saveVideo(
        context: Context,
        filePath: String,
        displayName: String,
        logger: Logger,
        deleteSourceOnSuccess: Boolean = false,
    ): String? = withContext(Dispatchers.IO) {
        saveToMediaStore(
            context = context,
            request = MediaStoreRequest(
                filePath = filePath,
                displayName = "$displayName.mp4",
                mimeType = "video/mp4",
                relativePath = "Movies/$FOLDER_NAME",
                collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
                } else {
                    MediaStore.Video.Media.EXTERNAL_CONTENT_URI
                },
                deleteSourceOnSuccess = deleteSourceOnSuccess,
            ),
            logger = logger,
        )
    }

    private fun saveToMediaStore(
        context: Context,
        request: MediaStoreRequest,
        logger: Logger,
    ): String? {
        val file = File(request.filePath)
        if (!file.exists()) {
            logger.w(TAG, "File not found: ${request.filePath}")
            return null
        }

        // Pre-Q public-gallery writes need WRITE_EXTERNAL_STORAGE, which we
        // intentionally don't declare. Keep the capture private (its path stays
        // usable for upload) instead of attempting a doomed MediaStore insert.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            logger.w(TAG, "Gallery publish needs API 29+; keeping ${request.filePath} private")
            return null
        }

        val resolver = context.contentResolver
        val contentValues = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, request.displayName)
            put(MediaStore.MediaColumns.MIME_TYPE, request.mimeType)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.MediaColumns.RELATIVE_PATH, request.relativePath)
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
        }

        var uri: Uri? = null
        return try {
            uri = resolver.insert(request.collection, contentValues)
                ?: throw IOException("Failed to create MediaStore record")

            resolver.openOutputStream(uri)?.use { outputStream ->
                file.inputStream().use { inputStream ->
                    inputStream.copyTo(outputStream)
                }
            } ?: throw IOException("Failed to get output stream")

            // Mark as complete (visible in gallery)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                contentValues.clear()
                contentValues.put(MediaStore.MediaColumns.IS_PENDING, 0)
                resolver.update(uri, contentValues, null, null)
            }

            // Move semantics: reclaim the private temp now that the gallery
            // has its own copy (preview path).
            if (request.deleteSourceOnSuccess) {
                runCatching { file.delete() }
            }

            logger.d(TAG, "Saved to gallery: ${request.displayName} → $uri")
            uri.toString()
        } catch (e: Exception) {
            // Broadened from IOException: resolver.insert/update can throw
            // SecurityException / IllegalStateException on some OEMs. Roll back the
            // orphaned IS_PENDING row so it doesn't linger (~7-day auto-expiry).
            logger.e(TAG, "Failed to save to gallery: ${e.message}", e)
            uri?.let { runCatching { resolver.delete(it, null, null) } }
            null
        }
    }
}
