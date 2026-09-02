package com.snabbit.runner.shared.core.network

import com.snabbit.runner.shared.core.CrashReporter
import com.snabbit.runner.shared.core.CurrentTimeMs
import com.snabbit.runner.shared.core.NowIso
import com.snabbit.runner.shared.core.network.interceptors.AuthInterceptor
import com.snabbit.runner.shared.core.network.interceptors.RequestInterceptor
import com.snabbit.runner.shared.core.network.interceptors.UnauthorizedResponseObserver
import com.snabbit.runner.shared.core.result.Result
import com.snabbit.runner.shared.core.storage.InMemoryEncryptedStore
import com.snabbit.runner.shared.core.storage.StoreManagerImpl
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpMethod
import io.ktor.http.HttpStatusCode
import kotlinx.coroutines.test.currentTime
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * The app-wide budget is not just carried — it is *spent*.
 *
 * Both tests drive the cold-start gate (a [NetworkConfigStore] that is never
 * pushed to), because that is the one place the connect budget is observable
 * without a real socket: `execute()` waits exactly that long for the Dart-pushed
 * config, then gives up with a transport error. `runTest`'s virtual clock makes
 * "exactly that long" assertable via `currentTime` — no wall-clock sleeping.
 */
class SnabbitHttpClientTimeoutTest {

    // A client whose NetworkConfigStore never receives a push, so every request
    // burns its full connect budget on the cold-start gate and then fails.
    private suspend fun wedgedClient(tuning: NetworkTuning): Pair<SnabbitHttpClient, MockEngine> {
        val engine = MockEngine { respond("ok", HttpStatusCode.OK, jsonHeaders()) }
        val storeManager = StoreManagerImpl(InMemoryEncryptedStore())
        storeManager.hydrateAll()
        val configStore = NetworkConfigStore()   // deliberately never pushed
        // ONE store across all three consumers, as the Koin graph does. This rig
        // previously let buildKtorClient and the 401 observer default to their own
        // private stores — harmless for these particular assertions, but the exact
        // silent-misconfiguration the required parameter now prevents.
        val tuningStore = fixedNetworkTuningStore(tuning)
        val client = SnabbitHttpClientImpl(
            httpClient = buildKtorClient(
                engine = engine,
                crashReporter = CrashReporter { _, _ -> },
                networkTuningStore = tuningStore,
                installTimeout = false,
            ),
            networkConfigStore = configStore,
            networkTuningStore = tuningStore,
            authInterceptor = AuthInterceptor(storeManager),
            requestInterceptor = RequestInterceptor(
                configStore,
                RequestIdGenerator(nowIso = NowIso { TEST_TIMESTAMP }),
            ),
            unauthorizedObserver = UnauthorizedResponseObserver(
                dispatcher = UnauthorizedDispatcher(),
                currentTimeMs = CurrentTimeMs { 0L },
                networkTuningStore = tuningStore,
            ),
            logger = SilentLogger,
            currentTimeMs = CurrentTimeMs { 0L },
        )
        return client to engine
    }

    @Test
    fun coldStartGate_spendsTheAppWideConnectBudget() = runTest {
        val (client, engine) = wedgedClient(NetworkTuning(connectTimeoutMs = 20_000L))
        val startedAt = currentTime

        val result = client.execute(SnabbitRequest(method = HttpMethod.Get, url = "/ping"))

        assertTrue(result is Result.Err, "a never-pushed config must fail the request, not hang it")
        assertEquals(20_000L, currentTime - startedAt, "gate must wait exactly the RC-driven budget")
        // No socket was ever opened — the request failed before the engine was reached.
        assertTrue(engine.requestHistory.isEmpty())
    }

    // Changing the RC value changes the observed behaviour: same wedged setup,
    // different budget, different time-to-failure. This is what a bad push would
    // move, and why the clamp floor exists.
    @Test
    fun coldStartGate_tracksAShorterAppWideBudget() = runTest {
        val (client, _) = wedgedClient(NetworkTuning(connectTimeoutMs = 5_000L))
        val startedAt = currentTime

        client.execute(SnabbitRequest(method = HttpMethod.Get, url = "/ping"))

        assertEquals(5_000L, currentTime - startedAt)
    }

    @Test
    fun perRequestOverride_winsOverTheAppWideBudget() = runTest {
        val (client, _) = wedgedClient(NetworkTuning(connectTimeoutMs = 120_000L))
        val startedAt = currentTime

        client.execute(
            SnabbitRequest(method = HttpMethod.Get, url = "/ping", connectTimeoutMs = 8_000L),
        )

        assertEquals(8_000L, currentTime - startedAt, "an explicit per-request budget must win")
    }

    @Test
    fun unsetRequestTimeouts_deferToTheStore() {
        // The whole lever depends on callers leaving these null; a non-null default
        // would silently opt every request out of Remote Config.
        val request = SnabbitRequest(method = HttpMethod.Get, url = "/ping")

        assertNull(request.connectTimeoutMs)
        assertNull(request.receiveTimeoutMs)
    }
}
