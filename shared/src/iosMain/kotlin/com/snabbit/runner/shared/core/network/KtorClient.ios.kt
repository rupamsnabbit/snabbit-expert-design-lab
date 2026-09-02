package com.snabbit.runner.shared.core.network

import io.ktor.client.engine.HttpClientEngine
import io.ktor.client.engine.darwin.Darwin

/**
 * iOS actuals for the Ktor client. [defaultHttpClientEngine] returns the Darwin (NSURLSession)
 * engine — mirrors the Android `OkHttp.create()`. [isTransientIoException] stays `false` for now
 * (no JVM IOException hierarchy on Native); NSURLError-based transient mapping is a follow-up, so
 * iOS simply won't classify transient network errors for retry until then.
 */
internal actual fun isTransientIoException(cause: Throwable): Boolean = false

actual fun defaultHttpClientEngine(): HttpClientEngine = Darwin.create()
