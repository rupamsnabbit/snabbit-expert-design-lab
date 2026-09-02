package com.snabbit.runner.shared.features.kavach

import com.snabbit.runner.shared.features.kavach.shield.data.store.ShieldFileReader

/** In-memory [ShieldFileReader] — returns [bytes] for any path, records deletes. */
class FakeShieldFileReader(var bytes: ByteArray? = byteArrayOf(1, 2, 3)) : ShieldFileReader {
    val deleted = mutableListOf<String>()
    override suspend fun read(path: String): ByteArray? = bytes
    override suspend fun delete(path: String) { deleted += path }
}
