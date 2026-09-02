package com.snabbit.runner.shared.features.kavach.shield.data.store

import android.app.Application
import com.snabbit.runner.shared.core.AppDispatchers
import java.io.File
import kotlinx.coroutines.withContext

/**
 * Writes the bundled model bytes to `cacheDir` once and returns the absolute path (ORT/TFLite
 * load from a file). Idempotent — reuses the cached file if present.
 */
internal class AndroidModelAssetResolver(
    private val app: Application,
    private val dispatchers: AppDispatchers,
    private val bytesProvider: suspend (String) -> ByteArray,
) : ModelAssetResolver {
    // Off the caller's thread — activate() runs on viewModelScope (Main) and the model is multi-MB,
    // so the read + disk write would jank/ANR on first activation (#anr).
    override suspend fun resolve(fileName: String): String = withContext(dispatchers.io) {
        try {
            val file = File(app.cacheDir, fileName)
            if (!file.exists() || file.length() == 0L) {
                val bytes = bytesProvider(fileName)
                if (bytes.isEmpty()) return@withContext ""
                // Atomic materialize: write to a temp then rename onto the final path. A crash/kill
                // mid-write then leaves the temp (re-materialized next run), never a truncated final file
                // that length()!=0 would serve as a valid — but corrupt — model. renameTo is atomic on the
                // same filesystem (cacheDir) and replaces a stale zero-length file on Android.
                // Unique temp name: a fixed "$fileName.tmp" would let two concurrent resolve(sameFile)
                // calls write the same temp and race the rename → a corrupt model. Keeps the write
                // self-contained regardless of caller serialization.
                val tmp = File(app.cacheDir, "$fileName.${System.nanoTime()}.tmp")
                tmp.writeBytes(bytes)
                if (!tmp.renameTo(file)) {
                    tmp.delete()
                    return@withContext ""
                }
            }
            file.absolutePath
        } catch (e: Throwable) {
            ""
        }
    }
}
