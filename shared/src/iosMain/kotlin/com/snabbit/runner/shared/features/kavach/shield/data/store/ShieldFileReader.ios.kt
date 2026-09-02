package com.snabbit.runner.shared.features.kavach.shield.data.store

import kotlinx.cinterop.ExperimentalForeignApi
import kotlinx.cinterop.addressOf
import kotlinx.cinterop.convert
import kotlinx.cinterop.usePinned
import platform.Foundation.NSData
import platform.Foundation.NSFileManager
import platform.Foundation.dataWithContentsOfFile
import platform.posix.memcpy

@OptIn(ExperimentalForeignApi::class)
private class IosShieldFileReader : ShieldFileReader {
    override suspend fun read(path: String): ByteArray? {
        val data = NSData.dataWithContentsOfFile(path) ?: return null
        val length = data.length.toInt()
        if (length == 0) return ByteArray(0)
        val bytes = ByteArray(length)
        bytes.usePinned { pinned -> memcpy(pinned.addressOf(0), data.bytes, data.length.convert()) }
        return bytes
    }

    override suspend fun delete(path: String) {
        NSFileManager.defaultManager.removeItemAtPath(path, null)
    }
}

internal actual fun platformShieldFileReader(): ShieldFileReader = IosShieldFileReader()
