package com.snabbit.runner.shared.core.image

import coil3.ImageLoader
import coil3.PlatformContext
import coil3.network.ktor3.KtorNetworkFetcherFactory
import coil3.request.crossfade
import io.ktor.client.HttpClient
import io.ktor.client.engine.HttpClientEngine
import io.ktor.client.plugins.HttpTimeout

/**
 * Builds the process-wide Coil [ImageLoader] behind [RemoteImage]. The host
 * installs it as the singleton at startup (Android:
 * `SingletonImageLoader.setSafe` in `KmpBootstrap`).
 *
 * The [engine] is injected, mirroring `buildKtorClient` — no SPI discovery
 * (Android passes `defaultHttpClientEngine()`, i.e. OkHttp; iOS wires Darwin
 * when its networking lands). Image traffic gets its own [HttpClient]: CDN
 * fetches must not ride the API client's auth/request interceptors.
 * Memory + disk caches are Coil's defaults.
 *
 * It does, however, need its own [HttpTimeout]. Without one the only limits
 * are OkHttp's per-socket defaults (10 s connect/read/write) with `callTimeout`
 * disabled — so a CDN that trickles bytes, the ordinary 2G failure mode, never
 * trips a read timeout and an AWOL breach image can stream indefinitely,
 * holding a connection and never resolving to [RemoteImage]'s draw-nothing
 * fallback. The budget is deliberately tighter than the API client's 60 s:
 * an image is decoration on a screen that has already rendered, so it should
 * give up long before a request the runner is actually blocked on.
 */
fun buildSnabbitImageLoader(
    context: PlatformContext,
    engine: HttpClientEngine,
): ImageLoader =
    ImageLoader.Builder(context)
        .components {
            add(
                KtorNetworkFetcherFactory(
                    HttpClient(engine) {
                        install(HttpTimeout) {
                            connectTimeoutMillis = 10_000
                            requestTimeoutMillis = 15_000
                            socketTimeoutMillis = 10_000
                        }
                    },
                ),
            )
        }
        .crossfade(true)
        .build()
