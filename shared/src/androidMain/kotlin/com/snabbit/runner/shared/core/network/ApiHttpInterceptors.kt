package com.snabbit.runner.shared.core.network

import okhttp3.Interceptor

/**
 * Host-provided OkHttp interceptors injected into the Android API [io.ktor.client.engine.HttpClientEngine]
 * (see `PlatformModule`). Empty/absent by default; the debug build supplies e.g. the Chucker
 * interceptor. Keeps `:shared` free of any debug-tooling dependency — only the stable
 * `okhttp3.Interceptor` type (already on the OkHttp-engine classpath) is referenced here.
 */
class ApiHttpInterceptors(val value: List<Interceptor>)
