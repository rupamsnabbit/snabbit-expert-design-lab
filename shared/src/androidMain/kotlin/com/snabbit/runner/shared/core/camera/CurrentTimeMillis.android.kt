package com.snabbit.runner.shared.core.camera

import java.security.SecureRandom

internal actual fun currentTimeMillis(): Long = System.currentTimeMillis()

private val secureRandom = SecureRandom()

internal actual fun secureRandomBytes(count: Int): ByteArray =
    ByteArray(count).also { secureRandom.nextBytes(it) }
