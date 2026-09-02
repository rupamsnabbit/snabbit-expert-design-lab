package com.snabbit.runner.shared.core.network.interceptors

import com.snabbit.runner.shared.core.CrashReporter
import io.ktor.client.plugins.api.Send
import io.ktor.client.plugins.api.createClientPlugin
import kotlinx.coroutines.CancellationException

/**
 * Configuration block for [NetworkExceptionPlugin]. The host (Koin) sets
 * [crashReporter] when assembling the HttpClient; tests can leave it
 * unset.
 */
class NetworkExceptionPluginConfig {
    var crashReporter: CrashReporter? = null
}

/**
 * Ktor plugin that wraps the entire send chain (§3.3). Installed FIRST
 * so its `on(Send)` is the outermost hook — retries and other plugins
 * run inside it. When the chain throws a transport exception:
 *
 *   1. CancellationException is rethrown immediately (structured concurrency).
 *   2. Any other Throwable is reported via the optional crashReporter
 *      with the URL + method as context, then rethrown.
 *   3. SnabbitHttpClient.execute() catches the rethrow and wraps the
 *      result as Result.Err(NetworkError.TransportError(…)).
 */
val NetworkExceptionPlugin = createClientPlugin(
    "NetworkExceptionPlugin",
    ::NetworkExceptionPluginConfig,
) {
    val crashReporter = pluginConfig.crashReporter

    on(Send) { request ->
        try {
            proceed(request)
        } catch (e: CancellationException) {
            throw e
        } catch (e: Throwable) {
            // Guard the reporter call: if crash reporting itself throws
            // (network/serialization failure inside Crashlytics, etc.) we
            // must not let it mask the original transport exception. The
            // caller depends on receiving `e` here for retry / error
            // mapping.
            try {
                crashReporter?.report(
                    e,
                    mapOf(
                        "url" to request.url.buildString(),
                        "method" to request.method.value,
                    ),
                )
            } catch (_: Throwable) {
                // Intentionally swallowed — original `e` is rethrown below.
            }
            throw e
        }
    }
}
