package com.snabbit.runner.shared.features.kavach.shield.data.store

import com.snabbit.runner.shared.core.AppDispatchers
import kotlinx.cinterop.ExperimentalForeignApi
import kotlinx.cinterop.addressOf
import kotlinx.coroutines.withContext
import kotlinx.cinterop.convert
import kotlinx.cinterop.usePinned
import platform.Foundation.NSCachesDirectory
import platform.Foundation.NSData
import platform.Foundation.NSFileManager
import platform.Foundation.NSFileSize
import platform.Foundation.NSNumber
import platform.Foundation.NSSearchPathForDirectoriesInDomains
import platform.Foundation.NSUserDomainMask
import platform.Foundation.create
import platform.Foundation.writeToFile

/**
 * Writes the bundled model bytes to the Caches dir once and returns the absolute path (ORT/TFLite
 * load from a file). Idempotent — reuses the cached file if present.
 */
@OptIn(ExperimentalForeignApi::class)
internal class IosModelAssetResolver(
    private val dispatchers: AppDispatchers,
    private val bytesProvider: suspend (String) -> ByteArray,
) : ModelAssetResolver {
    // Off the caller's (Main) thread + graceful empty-string on failure (the interface contract,
    // which Android honors) — else a multi-MB read janks Main (#anr) and a mis-bundled model throws
    // MissingResourceException out of shieldConfig(), failing the whole iOS shield start (#res).
    override suspend fun resolve(fileName: String): String = withContext(dispatchers.default) {
        try {
            val dir = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, true)
                .firstOrNull() as? String ?: return@withContext ""
            val path = "$dir/$fileName"
            val fm = NSFileManager.defaultManager
            // Absent OR zero-byte (interrupted write / cache purge) → (re)materialize — parity with the
            // Android resolver's `!exists() || length()==0L`, else a 0-byte model is served forever (#11).
            val size = (fm.attributesOfItemAtPath(path, null)?.get(NSFileSize) as? NSNumber)?.longLongValue ?: 0L
            if (size == 0L) {
                val bytes = bytesProvider(fileName)
                if (bytes.isEmpty()) return@withContext ""
                val data = bytes.usePinned { NSData.create(bytes = it.addressOf(0), length = bytes.size.convert()) }
                if (!data.writeToFile(path, atomically = true)) return@withContext ""
            }
            path
        } catch (e: Throwable) {
            ""
        }
    }
}
