package com.snabbit.runner.shared.core.camera.internal

import androidx.compose.ui.graphics.ImageBitmap
import com.snabbit.runner.shared.core.AppDispatchers
import com.snabbit.runner.shared.core.CrashReporter
import com.snabbit.runner.shared.core.camera.currentTimeMillis
import kotlinx.cinterop.BetaInteropApi
import kotlinx.cinterop.ExperimentalForeignApi
import kotlinx.cinterop.addressOf
import kotlinx.cinterop.usePinned
import kotlinx.coroutines.withContext
import platform.Foundation.NSFileManager
import platform.Foundation.NSNumber
import platform.Foundation.NSTemporaryDirectory
import platform.Foundation.NSData
import platform.Foundation.create
import platform.Foundation.writeToFile

internal actual fun platformFileOps(
    crashReporter: CrashReporter,
    dispatchers: AppDispatchers,
): PlatformFileOps = IosPlatformFileOps(crashReporter, dispatchers)

/**
 * iOS [PlatformFileOps]. File I/O is real (NSFileManager / NSData); image decode
 * and compression are stubbed until the iOS camera path is built (see
 * `CameraKProvider.ios`), so a preview decode returns `null` (surfacing the error
 * state) and compression passes the path through unchanged.
 */
internal class IosPlatformFileOps(
    private val crashReporter: CrashReporter,
    private val dispatchers: AppDispatchers,
) : PlatformFileOps {

    @OptIn(ExperimentalForeignApi::class)
    override fun fileSize(path: String): Long {
        val attrs = NSFileManager.defaultManager.attributesOfItemAtPath(path, null)
        // NSFileSize is an NSNumber; retrieved through an `Any?` map slot it does NOT
        // auto-unbox to a Kotlin Long (`as? Long` is always null → 0L). Read it as an
        // NSNumber and take longValue.
        return (attrs?.get("NSFileSize") as? NSNumber)?.longValue ?: 0L
    }

    @OptIn(ExperimentalForeignApi::class, BetaInteropApi::class)
    override suspend fun writeTempFile(bytes: ByteArray, prefix: String, suffix: String): String =
        withContext(dispatchers.io) {
            val tempDir = NSTemporaryDirectory()
            val fileName = "$prefix${currentTimeMillis()}$suffix"
            val path = "$tempDir$fileName"
            // NSData.create expects a C pointer into the byte buffer; pin the ByteArray
            // and hand over its address. Guard the empty case (addressOf(0) would throw).
            val data = if (bytes.isEmpty()) {
                NSData.create(bytes = null, length = 0uL)
            } else {
                bytes.usePinned { pinned ->
                    NSData.create(bytes = pinned.addressOf(0), length = bytes.size.toULong())
                }
            }
            data.writeToFile(path, atomically = true)
            path
        }

    @OptIn(ExperimentalForeignApi::class)
    override suspend fun deleteFile(path: String): Unit = withContext(dispatchers.io) {
        try {
            NSFileManager.defaultManager.removeItemAtPath(path, null)
            Unit
        } catch (e: Throwable) {
            // Best-effort cleanup — record instead of swallowing.
            crashReporter.report(e, mapOf("op" to "deleteFile"))
        }
    }

    override suspend fun loadDownsampledBitmap(
        path: String,
        reqWidthPx: Int,
        reqHeightPx: Int,
        mirrorHorizontally: Boolean,
    ): ImageBitmap? {
        // TODO(iOS launch): decode via CGImageSourceCreateThumbnailAtIndex →
        // Skia Image → ImageBitmap, applying [mirrorHorizontally]. iOS capture is
        // itself stubbed (see CameraKProvider.ios), so returning null here surfaces
        // the preview error state — acceptable until the iOS camera path is built.
        return null
    }

    override suspend fun compressImageToFit(path: String, maxBytes: Long): String {
        // TODO(iOS launch): re-encode via ImageIO (UIImageJPEGRepresentation /
        // CGImageDestination) when the iOS capture path is built. iOS capture is
        // stubbed, so pass the path through unchanged for now.
        return path
    }
}
