package com.snabbit.runner.shared.core.network

/**
 * iOS has no java.io / javax.net.ssl exception hierarchy — those branches
 * are JVM-only. Ktor's common-typed timeout exceptions are still matched by
 * the shared `NetworkExceptionMapper`, so this actual returns null and lets
 * the caller fall through to `AppErrorType.OTHER_ERROR`.
 *
 * Revisit when iOS networking lands: NSURLError domain codes can be mapped
 * to NO_INTERNET / SERVER_DOWN / INVALID_REQUEST here.
 */
internal actual fun mapPlatformException(cause: Throwable): AppErrorType? = null
