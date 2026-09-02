package com.snabbit.runner.shared.core.network

import io.ktor.client.engine.HttpClientEngine
import io.ktor.client.engine.okhttp.OkHttp
import java.io.IOException

/**
 * JVM-side actuals for the Ktor client (§3, §5).
 *
 * Hosts both:
 *  - [defaultHttpClientEngine] — returns Ktor's OkHttp engine. Bound in
 *    `PlatformModule` so production HTTP calls go through OkHttp. Tests
 *    bypass this entirely by passing a `MockEngine` directly to
 *    [buildKtorClient]; no SPI discovery, no classpath ambiguity.
 *  - [isTransientIoException] — flags IOException-family throwables as
 *    retryable. JVM-only because the IOException hierarchy doesn't exist
 *    on Apple platforms.
 */
internal actual fun isTransientIoException(cause: Throwable): Boolean = cause is IOException

actual fun defaultHttpClientEngine(): HttpClientEngine = OkHttp.create()
