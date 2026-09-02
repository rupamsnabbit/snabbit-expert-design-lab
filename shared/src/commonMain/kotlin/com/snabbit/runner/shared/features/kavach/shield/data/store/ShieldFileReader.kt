package com.snabbit.runner.shared.features.kavach.shield.data.store

/**
 * Reads + deletes the plugin's on-disk encrypted `.enc` clip (Step 7.4). The plugin emits a
 * `filePath`; the app reads the bytes for the upload BLOB, then deletes the file after enqueue.
 */
interface ShieldFileReader {
    suspend fun read(path: String): ByteArray?
    suspend fun delete(path: String)
}

internal expect fun platformShieldFileReader(): ShieldFileReader
