package com.snabbit.runner.shared.core.network

import com.snabbit.runner.shared.core.CrashReporter
import com.snabbit.runner.shared.core.network.interceptors.NetworkExceptionPlugin
import io.ktor.client.HttpClient
import io.ktor.client.HttpClientConfig
import io.ktor.client.engine.HttpClientEngine
import io.ktor.client.plugins.HttpRequestRetry
import io.ktor.client.plugins.HttpTimeout
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.client.plugins.logging.LogLevel
import io.ktor.client.plugins.logging.Logger
import io.ktor.client.plugins.logging.Logging
import io.ktor.http.HttpMethod
import io.ktor.serialization.kotlinx.json.json
import kotlinx.serialization.json.Json

/**
 * Largest exponent applied to the retry backoff base. 2^16 x a 5 s base already
 * exceeds every allowed [NetworkTuning.retryMaxDelayMs], so the cap costs nothing
 * behaviourally and keeps the shift far from Int/Long overflow.
 */
private const val MAX_BACKOFF_SHIFT: Int = 16

/**
 * Tags transient I/O failures the retry plugin should treat as retryable.
 * Platform-specific because the IOException family is JVM-only; iOS will
 * provide its own actual.
 */
internal expect fun isTransientIoException(cause: Throwable): Boolean

/**
 * Platform-default Ktor [HttpClientEngine]. Provided by `actual` in each
 * platform target — `OkHttp` on Android, `Darwin` on iOS (when iOS
 * networking lands).
 *
 * Used by [PlatformModule] to bind `single<HttpClientEngine>` so Koin
 * resolves the engine like any other dependency. Tests override this
 * binding with a `MockEngine` instead of relying on Ktor's SPI discovery
 * — SPI is classpath-order-dependent and becomes non-deterministic when
 * both production and mock engines are on the test classpath.
 */
expect fun defaultHttpClientEngine(): HttpClientEngine

/**
 * Builds the Ktor [HttpClient] with all plugins installed (§3, §5, §6).
 * Engine is **required** — no SPI discovery fallback. Production binds
 * [defaultHttpClientEngine] via Koin; tests pass a `MockEngine` directly.
 *
 * Retry policy (§5): max 2 retries on 502/503/504 or transient I/O,
 * idempotent methods only (GET/PUT/HEAD), exponential backoff capped at
 * 5s. POST never retries.
 */
fun buildKtorClient(
    engine: HttpClientEngine,
    crashReporter: CrashReporter,
    /**
     * Supplies the live retry policy. Read inside the retry predicates and the
     * delay lambda — both of which Ktor evaluates *per attempt* — so an RC
     * refresh takes effect without rebuilding the client (which Koin holds as a
     * `single` for the process lifetime).
     *
     * Required, deliberately: a default would let a caller silently get a private
     * store that nothing ever refreshes, leaving that client permanently on the
     * shipped defaults with no error and no log. The RC lever would just quietly
     * not work for it. Pass the Koin singleton.
     */
    networkTuningStore: NetworkTuningStore,
    /**
     * Whether to install HttpTimeout. Always true in production; tests set
     * this false when driving the client under [kotlinx.coroutines.test.runTest]
     * because runTest auto-advances virtual time, which causes the
     * timeout coroutine to fire spuriously before the (in-process)
     * MockEngine can respond.
     */
    installTimeout: Boolean = true,
    // OFF by default: LogLevel.BODY dumps request/response bodies (auth
    // tokens, OTPs, PII) to stdout/logcat, which must never ship. Enable only
    // for local debugging; the eventual prod path should gate on
    // BuildConfig.DEBUG via a host-injected flag, not a hardcoded true.
    enableLogging: Boolean = false,
    configure: HttpClientConfig<*>.() -> Unit = {},
): HttpClient {
    val block: HttpClientConfig<*>.() -> Unit = {
        expectSuccess = false   // We handle 4xx/5xx by mapping to NetworkError.HttpError ourselves

        if (enableLogging) {
            install(Logging) {
                logger = object : Logger {
                    override fun log(message: String) = println(message)
                }
                level = LogLevel.BODY
            }
        }

        install(NetworkExceptionPlugin) {
            this.crashReporter = crashReporter
        }

        install(ContentNegotiation) {
            json(
                Json {
                    ignoreUnknownKeys = true
                    isLenient = true
                    encodeDefaults = false
                },
            )
        }

        // Client-wide backstop only. Every call routed through
        // `SnabbitHttpClientImpl.execute()` sets a per-request `timeout { }` from
        // the RC-driven `NetworkTuning`, and a per-request block wins over this
        // one — so these values govern nothing but a hypothetical direct use of
        // the raw client. Tune `expert_kmp_network_*_timeout_secs`, not this.
        if (installTimeout) {
            install(HttpTimeout) {
                connectTimeoutMillis = NetworkTuning.DEFAULT_CONNECT_TIMEOUT_MS
                requestTimeoutMillis = NetworkTuning.DEFAULT_RECEIVE_TIMEOUT_MS
                socketTimeoutMillis = NetworkTuning.DEFAULT_RECEIVE_TIMEOUT_MS
            }
        }

        install(HttpRequestRetry) {
            // Ktor reads `maxRetries` ONCE, at install time, and Koin builds this
            // client as a process-lived `single` — so this cannot be the RC value or
            // a refresh would never take effect. Install the ceiling instead and
            // enforce the live limit inside the predicates below, which Ktor DOES
            // evaluate per attempt. `expert_kmp_network_max_retries` is what governs.
            maxRetries = NetworkTuning.MAX_MAX_RETRIES
            // §5: retry only for idempotent methods, status 502/503/504, or
            // transient I/O. POST is never retried (§5.4).
            val idempotentMethods = listOf(HttpMethod.Get, HttpMethod.Put, HttpMethod.Head)
            retryIf { request, response ->
                retryCount <= networkTuningStore.snapshot().maxRetries &&
                    response.status.value in listOf(502, 503, 504) &&
                    request.method in idempotentMethods
            }
            retryOnExceptionIf { request, cause ->
                retryCount <= networkTuningStore.snapshot().maxRetries &&
                    isTransientIoException(cause) && request.method in idempotentMethods
            }
            // respectRetryAfterHeader = false: with the default (true) Ktor takes the
            // MAXIMUM of our computed backoff and any `Retry-After` the server sends, so
            // a header value outranks retryMaxDelayMs entirely — a misconfigured or
            // hostile origin could park a runner mid-job for an hour, and the RC "max
            // delay" we advertise would not be a ceiling at all. This client talks only
            // to Snabbit's own hosts, and when the backend genuinely needs us to back
            // off further that is now an RC push rather than a per-response header.
            delayMillis(respectRetryAfterHeader = false) { retryCount ->
                val tuning = networkTuningStore.snapshot()
                // Shift is bounded independently of MAX_MAX_RETRIES rather than relying on it:
                // `1 shl 31` is negative, which would sail through coerceAtMost and hand
                // `delay()` a negative value — i.e. silently no backoff at all. The coupling
                // between the ceiling constant and this arithmetic is otherwise invisible, so
                // raising MAX_MAX_RETRIES later would be a subtle way to remove backoff.
                val factor = 1L shl retryCount.coerceIn(0, MAX_BACKOFF_SHIFT)
                (tuning.retryBaseDelayMs * factor).coerceAtMost(tuning.retryMaxDelayMs)
            }
        }

        configure()
    }

    return HttpClient(engine, block)
}
