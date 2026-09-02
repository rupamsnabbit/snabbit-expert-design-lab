package com.snabbit.runner.shared.core.camera

import android.webkit.WebResourceResponse
import androidx.webkit.WebViewAssetLoader
import com.snabbit.runner.shared.core.Logger
import java.io.File
import java.io.FileInputStream
import java.util.concurrent.ConcurrentHashMap

/**
 * Serves captured images and videos from disk via `WebViewAssetLoader` so that
 * a URL like `https://appassets.androidplatform.net/captures/<token>.jpg`
 * is intercepted by the WebView's native networking layer and streamed
 * directly from the app-private file — **no media bytes cross the JS bridge**.
 *
 * Implements [CaptureIndex]: construct the [CaptureRegistry] with this handler as
 * its `index`, so the registry drives put/remove and this class holds the ONE
 * synchronous token→path map the WebView callback reads. (The registry's own
 * [CaptureRegistry.resolve] is `suspend` and can't be called from the callback.)
 *
 * Ported from Flutter's `capture_path_handler.dart`. Registered at `/captures/`.
 *
 * @param capturesDir when non-null, only files resolving *under* this directory
 *   are served — defense in depth for the day a token is ever derived into a path
 *   (today it's an opaque map key, so traversal is already impossible).
 */
class CapturePathHandler(
    private val logger: Logger,
    private val capturesDir: File? = null,
) : WebViewAssetLoader.PathHandler, CaptureIndex {

    /**
     * Synchronous token→path mirror. `WebViewAssetLoader.PathHandler.handle()`
     * runs on a WebView **worker thread** (not the main thread) while registry
     * updates arrive from the coroutine world — so this MUST be thread-safe.
     */
    private val registeredPaths = ConcurrentHashMap<String, String>()

    override fun put(token: String, filePath: String) {
        registeredPaths[token] = filePath
    }

    override fun remove(token: String) {
        registeredPaths.remove(token)
    }

    override fun handle(path: String): WebResourceResponse? {
        // Path arrives as e.g. "1716825600000_0.jpg" or "1716825600000_0.mp4".
        val filename = path.substringAfterLast("/")
        val token: String
        val contentType: String
        val maxSize: Long

        when {
            filename.endsWith(".jpg") || filename.endsWith(".jpeg") -> {
                token = filename.substringBeforeLast(".")
                contentType = "image/jpeg"
                maxSize = CaptureRegistry.MAX_PHOTO_SIZE_BYTES
            }
            filename.endsWith(".mp4") -> {
                token = filename.substringBeforeLast(".")
                contentType = "video/mp4"
                maxSize = CaptureRegistry.MAX_VIDEO_SIZE_BYTES
            }
            else -> {
                // No extension — assume photo token.
                token = filename
                contentType = "image/jpeg"
                maxSize = CaptureRegistry.MAX_PHOTO_SIZE_BYTES
            }
        }

        val filePath = registeredPaths[token]
        if (filePath == null) {
            logger.d(TAG, "Serve miss: token=$token, reason=unknown_or_expired")
            return notFound()
        }

        val file = File(filePath)
        // Must be a regular file, and (when a root is configured) resolve under it.
        if (!file.isFile || !file.isWithin(capturesDir)) {
            logger.d(TAG, "Serve miss: token=$token, reason=file_missing_or_out_of_scope")
            return notFound()
        }

        val fileLength = file.length()
        if (fileLength > maxSize) {
            logger.w(TAG, "Serve rejected: token=$token, size=$fileLength, max=$maxSize")
            return notFound()
        }

        logger.d(TAG, "Serve hit: token=$token, size=$fileLength, type=$contentType")

        // Served same-origin inside the app's own WebView — no CORS headers, and
        // the token is never echoed back.
        return WebResourceResponse(
            contentType,
            null, // encoding — null for binary
            200,
            "OK",
            mapOf(
                "Cache-Control" to "no-store",
                "Content-Length" to fileLength.toString(),
            ),
            FileInputStream(file),
        )
    }

    /** True if [root] is null, or this file canonically resolves under [root]. */
    private fun File.isWithin(root: File?): Boolean {
        if (root == null) return true
        return runCatching {
            canonicalPath.startsWith(root.canonicalPath + File.separator)
        }.getOrDefault(false)
    }

    companion object {
        private const val TAG = "CapturePathHandler"

        /** 404 with no body — no CORS headers (same-origin only). */
        private fun notFound(): WebResourceResponse =
            WebResourceResponse("text/plain", "utf-8", 404, "Not Found", emptyMap(), null)
    }
}
