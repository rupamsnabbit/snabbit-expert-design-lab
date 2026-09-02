package com.snabbit.runner.shared.core.network

import com.snabbit.runner.shared.core.CrashReporter
import com.snabbit.runner.shared.core.CurrentTimeMs
import com.snabbit.runner.shared.core.Logger
import com.snabbit.runner.shared.core.NowIso
import com.snabbit.runner.shared.core.config.RemoteConfigGateway
import com.snabbit.runner.shared.core.network.interceptors.AuthInterceptor
import com.snabbit.runner.shared.core.network.interceptors.RequestInterceptor
import com.snabbit.runner.shared.core.network.interceptors.UnauthorizedResponseObserver
import com.snabbit.runner.shared.core.storage.InMemoryEncryptedStore
import com.snabbit.runner.shared.core.storage.StoreManager
import com.snabbit.runner.shared.core.storage.StoreManagerImpl
import io.ktor.client.engine.mock.MockEngine
import io.ktor.http.HttpHeaders
import io.ktor.http.headersOf

internal const val TEST_BASE_URL = "https://test.snabbit.com/"
internal const val TEST_VERSION_CODE = "100"
internal const val TEST_TIMESTAMP = "2026-05-12T10:30:45.123"

/** Standard JSON Content-Type headers for MockEngine responses. */
internal fun jsonHeaders() = headersOf(HttpHeaders.ContentType, "application/json")

/**
 * Records every fire of [UnauthorizedDispatcher.dispatch] so tests can
 * assert call count. Constructed by installing an emitter that increments
 * the counter — mirrors how the production bridge installs an emitter.
 */
internal class RecordingUnauthorizedDispatcher {
    var fireCount = 0
        private set

    val dispatcher: UnauthorizedDispatcher = UnauthorizedDispatcher().also {
        it.setEmitter { fireCount++ }
    }
}

/** No-op [Logger] for tests that don't assert on log output. */
internal object SilentLogger : Logger {
    override fun d(tag: String, message: String) {}
    override fun w(tag: String, message: String, throwable: Throwable?) {}
    override fun e(tag: String, message: String, throwable: Throwable?) {}
}

/**
 * Test rig that wires every collaborator with sensible defaults and the
 * supplied [MockEngine]. Override individual params as needed.
 *
 * Suspending because [StoreManager.pushToken] is suspending — tests
 * already run inside `runTest { ... }` so this is transparent.
 */
internal suspend fun makeTestClient(
    engine: MockEngine,
    token: String? = "test-token",
    baseUrl: String = TEST_BASE_URL,
    versionCode: String = TEST_VERSION_CODE,
    nowIso: NowIso = NowIso { TEST_TIMESTAMP },
    currentTimeMs: CurrentTimeMs = CurrentTimeMs { 0L },
    unauthorizedDispatcher: UnauthorizedDispatcher = UnauthorizedDispatcher(),
    crashReporter: CrashReporter = CrashReporter { _, _ -> },
    maxResponseBytes: Long = SnabbitHttpClientImpl.DEFAULT_MAX_RESPONSE_BYTES,
    /** App-wide timeout budget; defaults to the shipped fallbacks (60 s / 60 s). */
    networkTuning: NetworkTuning = NetworkTuning(),
): SnabbitHttpClient {
    val storeManager: StoreManager = StoreManagerImpl(InMemoryEncryptedStore())
    if (token != null) storeManager.pushToken(token)
    // Mirror the production cold-start hydrate so AuthInterceptor.resolveToken()
    // (which awaits hydration) resolves immediately in tests.
    storeManager.hydrateAll()
    val configStore = NetworkConfigStore().also { it.pushNetworkConfig(baseUrl, versionCode) }
    val auth = AuthInterceptor(storeManager)
    val request = RequestInterceptor(configStore, RequestIdGenerator(nowIso = nowIso))
    // ONE store for all three consumers, mirroring the Koin graph — so a test that
    // tunes retries sees it in the Ktor plugin and in the client alike.
    val tuningStore = fixedNetworkTuningStore(networkTuning)
    val observer = UnauthorizedResponseObserver(unauthorizedDispatcher, currentTimeMs, tuningStore)

    val ktor = buildKtorClient(
        engine = engine,
        crashReporter = crashReporter,
        networkTuningStore = tuningStore,
        installTimeout = false,   // see buildKtorClient kdoc — runTest + HttpTimeout don't mix.
    )

    return SnabbitHttpClientImpl(
        httpClient = ktor,
        networkConfigStore = configStore,
        networkTuningStore = tuningStore,
        authInterceptor = auth,
        requestInterceptor = request,
        unauthorizedObserver = observer,
        logger = SilentLogger,
        currentTimeMs = currentTimeMs,
        maxResponseBytes = maxResponseBytes,
    )
}

/**
 * [NetworkTuningStore] pre-loaded with a fixed [NetworkTuning] — lets a test pin
 * the app-wide budget without standing up a Remote Config gateway.
 *
 * Suspending rather than blocking on purpose: the store's only mutator is
 * `refresh(rc)`, and `runBlocking` is not a `commonMain`/`commonTest` API in a
 * KMP module. Callers are already inside `runTest`, so awaiting is free.
 */
internal suspend fun fixedNetworkTuningStore(tuning: NetworkTuning): NetworkTuningStore =
    NetworkTuningStore().also { store ->
        // Answer in the units the RC keys are authored in (timeouts in seconds, the
        // rest in ms) so the store runs its real parse + clamp path rather than being
        // back-doored with pre-resolved values.
        store.refresh(
            FakeIntRemoteConfigGateway(
                mapOf(
                    NetworkTuning.KEY_CONNECT_TIMEOUT_SECS to (tuning.connectTimeoutMs / 1_000).toInt(),
                    NetworkTuning.KEY_RECEIVE_TIMEOUT_SECS to (tuning.receiveTimeoutMs / 1_000).toInt(),
                    NetworkTuning.KEY_MAX_RETRIES to tuning.maxRetries,
                    NetworkTuning.KEY_RETRY_BASE_DELAY_MS to tuning.retryBaseDelayMs.toInt(),
                    NetworkTuning.KEY_RETRY_MAX_DELAY_MS to tuning.retryMaxDelayMs.toInt(),
                    NetworkTuning.KEY_UNAUTHORIZED_DEBOUNCE_MS to tuning.unauthorizedDebounceMs.toInt(),
                ),
            ),
        )
    }

/** Minimal [RemoteConfigGateway] that answers int keys from a map; everything else is the default. */
internal class FakeIntRemoteConfigGateway(private val ints: Map<String, Int>) : RemoteConfigGateway {
    override suspend fun getBoolean(key: String, default: Boolean) = default
    override suspend fun getInt(key: String, default: Int) = ints[key] ?: default
    override suspend fun getDouble(key: String, default: Double) = default
    override suspend fun getString(key: String, default: String) = default
    override suspend fun getStringList(key: String, default: List<String>) = default
    override suspend fun fetchAndActivate() = false
}
