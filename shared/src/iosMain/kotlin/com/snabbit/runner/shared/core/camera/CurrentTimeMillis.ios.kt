package com.snabbit.runner.shared.core.camera

import kotlinx.cinterop.ExperimentalForeignApi
import kotlinx.cinterop.addressOf
import kotlinx.cinterop.usePinned
import platform.Foundation.NSDate
import platform.Foundation.timeIntervalSince1970
import platform.Security.SecRandomCopyBytes
import platform.Security.kSecRandomDefault

internal actual fun currentTimeMillis(): Long =
    (NSDate().timeIntervalSince1970 * 1000).toLong()

@OptIn(ExperimentalForeignApi::class)
internal actual fun secureRandomBytes(count: Int): ByteArray {
    val bytes = ByteArray(count)
    if (count > 0) {
        bytes.usePinned { pinned ->
            SecRandomCopyBytes(kSecRandomDefault, count.toULong(), pinned.addressOf(0))
        }
    }
    return bytes
}
