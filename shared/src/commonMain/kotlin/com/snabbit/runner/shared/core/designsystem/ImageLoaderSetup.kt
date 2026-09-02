package com.snabbit.runner.shared.core.designsystem

import coil3.ImageLoader
import coil3.SingletonImageLoader
import coil3.network.ktor3.KtorNetworkFetcherFactory

/**
 * Registers the process-wide Coil [ImageLoader] with a **Ktor-backed** network
 * fetcher, so `AsyncImage(url)` (e.g. the Profile photo via `ProfileAsyncImage`)
 * can load remote images. The resulting loader carries Coil's default **memory +
 * disk caches** — the KMP equivalent of Flutter's `cached_network_image`.
 * Without this, Coil's singleton has no network component and URL-backed images
 * silently fail.
 *
 * Call **once** at app startup (from `KmpBootstrap.initialize`). Idempotent-safe via
 * [SingletonImageLoader.setSafe] (a second set is ignored). Multiplatform — the Ktor
 * engine is provided per-platform (OkHttp on Android, Darwin on iOS), already on the
 * classpath.
 */
fun initSnabbitImageLoader() {
    SingletonImageLoader.setSafe { context ->
        ImageLoader.Builder(context)
            .components { add(KtorNetworkFetcherFactory()) }
            .build()
    }
}
