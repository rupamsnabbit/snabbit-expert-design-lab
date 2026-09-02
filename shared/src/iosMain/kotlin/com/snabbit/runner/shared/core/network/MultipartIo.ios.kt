package com.snabbit.runner.shared.core.network

import kotlinx.cinterop.ExperimentalForeignApi
import kotlinx.cinterop.addressOf
import kotlinx.cinterop.usePinned
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import platform.Foundation.NSData
import platform.Foundation.dataWithContentsOfFile
import platform.posix.memcpy

@OptIn(ExperimentalForeignApi::class)
internal actual suspend fun readFileBytes(path: String): ByteArray = withContext(Dispatchers.Default) {
    val data = NSData.dataWithContentsOfFile(path)
        ?: error("readFileBytes: cannot read file at $path")
    // Guard before the narrowing cast: NSUInteger -> Int truncates above 2 GB,
    // which would make `ByteArray(length)` throw on a negative size while `memcpy`
    // still copies the full `data.length`. Selfies never hit this, but this is the
    // shared upload path now.
    if (data.length > Int.MAX_VALUE.toULong()) {
        error("readFileBytes: file at $path is too large (${data.length} bytes)")
    }
    val length = data.length.toInt()
    val bytes = ByteArray(length)
    if (length > 0) {
        bytes.usePinned { pinned -> memcpy(pinned.addressOf(0), data.bytes, data.length) }
    }
    bytes
}
