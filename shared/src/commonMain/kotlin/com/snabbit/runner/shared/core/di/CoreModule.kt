package com.snabbit.runner.shared.core.di

import com.snabbit.runner.shared.core.alarm.AlarmController
import com.snabbit.runner.shared.core.appconfig.AppConfigStore
import com.snabbit.runner.shared.core.config.RemoteConfigGateway
import com.snabbit.runner.shared.core.config.remoteConfigGateway
import com.snabbit.runner.shared.core.deeplink.DeeplinkDispatcher
import com.snabbit.runner.shared.core.session.RunnerSessionStore
import com.snabbit.runner.shared.core.network.NetworkConfigStore
import com.snabbit.runner.shared.core.network.NetworkTuningStore
import com.snabbit.runner.shared.core.network.RequestIdGenerator
import com.snabbit.runner.shared.core.network.SnabbitHttpClient
import com.snabbit.runner.shared.core.network.SnabbitHttpClientImpl
import com.snabbit.runner.shared.core.network.UnauthorizedDispatcher
import com.snabbit.runner.shared.core.network.buildKtorClient
import com.snabbit.runner.shared.core.network.interceptors.AuthInterceptor
import com.snabbit.runner.shared.core.network.interceptors.RequestInterceptor
import com.snabbit.runner.shared.core.network.interceptors.UnauthorizedResponseObserver
import com.snabbit.runner.shared.core.storage.StoreManager
import com.snabbit.runner.shared.core.storage.StoreManagerImpl
import com.snabbit.runner.shared.core.runnerstate.RunnerStateStore
import com.snabbit.runner.shared.core.localization.LocalizationStore
import org.koin.dsl.module

/**
 * Platform-free Koin module (§14.2). Wires the network + storage layer
 * objects every feature depends on. The platform side ([platformModule])
 * supplies the Android-specific dependencies (Logger, AppDispatchers,
 * EncryptedStore, crash reporter, CurrentTimeMs, NowIso). The 401
 * dispatcher lives here ([UnauthorizedDispatcher]) — pure Kotlin, no
 * platform deps.
 *
 * No named qualifiers anywhere — every binding is disambiguated by its
 * own concrete type. Time suppliers are `CurrentTimeMs` / `NowIso` rather
 * than raw `() -> Long` / `() -> String` (which both erase to `Function0`
 * at runtime and forced reliance on named() for disambiguation).
 *
 * Multi-`get()` bindings use named parameters for readability — the
 * reader can see what's being injected without looking up the
 * constructor.
 */
val coreModule = module {
    // -- Storage --
    single<StoreManager> { StoreManagerImpl(store = get()) }

    // -- Runner real-time state (mirrored from Flutter over the bridge) --
    single { RunnerStateStore(logger = get()) }

    // -- Localization i18n map (mirrored from Flutter's LanguageProvider over the bridge) --
    // preferenceStorage via getOrNull(): unbound on iOS (no storage module wired
    // there yet), so the store degrades to in-memory-only rather than crashing.
    single {
        LocalizationStore(
            logger = get(),
            crashReporter = get(),
            preferenceStorage = getOrNull(),
            dispatchers = get(),
        )
    }

    // -- App config document (mirrored from Flutter's startup fetch) --
    single { AppConfigStore(logger = get()) }

    // -- Per-session scalars mirrored from Flutter (profile id, RC flags) --
    single { RunnerSessionStore() }

    // -- Remote Config (generic, platform-native) --
    // Android reads Firebase RC directly via the official SDK (B-native — no Flutter/Pigeon bridge);
    // iOS falls back to defaults until its native impl lands. Features consume this typed port.
    single<RemoteConfigGateway> { remoteConfigGateway() }

    // -- Alert-alarm silence seam (host-owned audio; Android binds the bridge) --
    // Pure Kotlin, no platform deps — unbound it is a no-op, so iOS and tests
    // resolve it safely.
    single { AlarmController() }

    // -- Network plumbing --
    single { NetworkConfigStore(preferenceStorage = get(), dispatchers = get()) }
    // App-wide, RC-driven HTTP timeout budget. Constructed with the shipped
    // defaults already in place and refreshed by KmpBootstrap after the launch
    // fetchAndActivate — so it never gates a request that fires before RC lands.
    single { NetworkTuningStore(logger = get()) }
    single { UnauthorizedDispatcher() }
    // Resolved AppsFlyer OneLink (UDL) params bridge — pure Kotlin, no platform
    // deps (mirrors UnauthorizedDispatcher). Android `DeeplinkPlugin` wires the
    // emitter; the AppsFlyer provider's UDL listener calls dispatch.
    single { DeeplinkDispatcher() }
    single { AuthInterceptor(storeManager = get()) }
    single { RequestIdGenerator(nowIso = get()) }
    single {
        RequestInterceptor(
            networkConfigStore = get(),
            requestIdGenerator = get(),
        )
    }
    single {
        UnauthorizedResponseObserver(
            dispatcher = get(),
            currentTimeMs = get(),
            networkTuningStore = get(),
        )
    }

    // -- HTTP client --
    single {
        // Engine is injected (HttpClientEngine bound in platformModule).
        // No SPI discovery — tests bind MockEngine via a test module
        // instead of relying on classpath ordering.
        // Network logging is OFF in shipped builds — LogLevel.BODY prints
        // request/response bodies (auth tokens, OTPs, PII) to stdout/logcat.
        // Flip `enableLogging = true` locally when debugging a request; do not
        // commit it on. (Proper BuildConfig.DEBUG gating is deferred until the
        // host threads an isDebug flag through KmpBootstrap.)
        buildKtorClient(
            engine = get(),
            crashReporter = get(),
            // Same singleton the http client and the 401 observer read — one RC
            // refresh moves timeouts, retry policy and debounce together.
            networkTuningStore = get(),
        )
    }
    single<SnabbitHttpClient> {
        SnabbitHttpClientImpl(
            httpClient = get(),
            networkConfigStore = get(),
            networkTuningStore = get(),
            authInterceptor = get(),
            requestInterceptor = get(),
            unauthorizedObserver = get(),
            logger = get(),
            currentTimeMs = get(),
        )
    }
}
