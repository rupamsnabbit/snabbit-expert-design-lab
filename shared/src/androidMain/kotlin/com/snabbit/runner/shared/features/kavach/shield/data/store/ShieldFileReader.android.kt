package com.snabbit.runner.shared.features.kavach.shield.data.store

import java.io.File

private class AndroidShieldFileReader : ShieldFileReader {
    override suspend fun read(path: String): ByteArray? =
        runCatching { File(path).takeIf { it.exists() }?.readBytes() }.getOrNull()

    override suspend fun delete(path: String) {
        runCatching { File(path).delete() }
    }
}

internal actual fun platformShieldFileReader(): ShieldFileReader = AndroidShieldFileReader()
