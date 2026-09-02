package com.snabbit.runner.shared.core.di

import android.app.Application
import com.snabbit.runner.shared.core.AppDispatchers
import com.snabbit.runner.shared.core.CrashReporter
import com.snabbit.runner.shared.core.CurrentTimeMs
import com.snabbit.runner.shared.core.Logger
import com.snabbit.runner.shared.core.NowIso
import com.snabbit.runner.shared.core.connectivity.AndroidNetworkMonitor
import com.snabbit.runner.shared.core.connectivity.NetworkMonitor
import com.snabbit.runner.shared.features.job.data.contact.AndroidCustomerContactLauncher
import com.snabbit.runner.shared.features.job.data.contact.CustomerContactLauncher
import com.snabbit.runner.shared.core.camera.ui.AndroidDeviceMemory
import com.snabbit.runner.shared.core.camera.ui.DeviceMemory
import com.snabbit.runner.shared.core.defaultAppDispatchers
import com.snabbit.runner.shared.core.defaultLogger
import com.snabbit.runner.shared.core.network.ApiHttpInterceptors
import com.snabbit.runner.shared.core.network.defaultHttpClientEngine
import com.snabbit.runner.shared.core.storage.EncryptedStore
import com.snabbit.runner.shared.core.storage.TinkDataStoreEncryptedStore
import com.snabbit.runner.shared.core.connectivity.ConnectivityFactory
import com.snabbit.runner.shared.core.device.AndroidBatteryMonitor
import com.snabbit.runner.shared.core.device.AndroidStorageMonitor
import com.snabbit.runner.shared.core.device.BatteryMonitor
import com.snabbit.runner.shared.core.device.StorageMonitor
import com.snabbit.runner.shared.features.kavach.shield.data.store.AndroidModelAssetResolver
import com.snabbit.runner.shared.features.kavach.shield.data.store.AndroidShieldAssetReader
import com.snabbit.runner.shared.features.kavach.shield.data.store.ModelAssetResolver
import com.snabbit.runner.shared.features.kavach.shield.data.store.ShieldAssetReader
import com.snabbit.runner.shared.features.kavach.shield.data.db.ShieldDbDriverFactory
import com.snabbit.runner.shared.features.job.domain.audio.AndroidJobCueAudioPlayer
import com.snabbit.runner.shared.features.job.domain.audio.JobCueAudioPlayer
import com.snabbit.runner.shared.features.kavach.sos.domain.deterrence.AndroidDeterrenceAudioPlayer
import com.snabbit.runner.shared.features.kavach.sos.domain.deterrence.DeterrenceAudioPlayer
import io.ktor.client.engine.HttpClientEngine
import io.ktor.client.engine.okhttp.OkHttp
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.SupervisorJob
import org.koin.dsl.module
import java.time.Instant

/**
 * Android-side bindings for [coreModule] (§14.2).
 *
 *  - [app] — the `Application` instance. Typed as `Application` (not
 *    `Context`) so callers can't accidentally pass an `Activity` /
 *    `Service` context, which would leak when held by long-lived
 *    singletons like `TinkDataStoreEncryptedStore`.
 *  - [crashReporter] — optional. If `null`, the module binds a no-op so
 *    `coreModule.get<CrashReporter>()` is always resolvable (no `getOrNull()`
 *    contortions, no conditional registration).
 *
 * The 401 dispatcher used to be a parameter; it is now a Koin singleton
 * bound in [coreModule] ([com.snabbit.runner.shared.core.network.UnauthorizedDispatcher]).
 * The Android bridge installs / clears its emitter on Flutter EventChannel
 * attach/detach.
 *
 * Time suppliers are typed [CurrentTimeMs] / [NowIso] interfaces rather
 * than raw `() -> Long` / `() -> String` — distinct runtime types so Koin
 * resolves them without named qualifiers, and callers can't accidentally
 * receive the wrong supplier through type erasure on `Function0`.
 */
fun platformModule(
    app: Application,
    crashReporter: ((Throwable, Map<String, String>) -> Unit)? = null,
) = module {
    single<Logger> { defaultLogger() }
    single<AppDispatchers> { defaultAppDispatchers() }
    single<CrashReporter> {
        // Wrap the host-supplied lambda as a CrashReporter so consumers
        // inject a distinct type (avoids JVM Function2 erasure colliding
        // with other Koin-bound lambdas). When the host omits the reporter
        // we don't silently drop — log a warning so the throwable still
        // surfaces somewhere observable.
        val log = get<Logger>()
        CrashReporter { t, m ->
            crashReporter?.invoke(t, m) ?: log.w(
                "CrashReporter",
                "not configured; dropping: ${t.message}",
                t,
            )
        }
    }
    // Camera budget-device safeguard (drives the capture-quality downgrade). Holds
    // the Application context — safe for a long-lived singleton (no Activity leak).
    single<DeviceMemory> { AndroidDeviceMemory(app) }
    single<EncryptedStore> { TinkDataStoreEncryptedStore(app, get()) }
    // Engine creation is explicit-lazy: nothing forces it at Koin start,
    // so the OkHttp thread pool isn't spun up until the first HTTP call.
    // Paired with [com.snabbit.runner.shared.core.KmpBootstrap.terminate]
    // which closes it on app shutdown — Ktor manually-created engines
    // must be closed by the owner, the HttpClient won't dispose them.
    single<HttpClientEngine>(createdAtStart = false) {
        // Host may inject OkHttp interceptors (debug-only Chucker). None → the plain default engine.
        val extra = getOrNull<ApiHttpInterceptors>()?.value.orEmpty()
        if (extra.isEmpty()) defaultHttpClientEngine()
        else OkHttp.create { extra.forEach { addInterceptor(it) } }
    }
    single<CurrentTimeMs> { CurrentTimeMs { System.currentTimeMillis() } }
    single<NowIso> { NowIso { Instant.now().toString() } }
    // Device connectivity for the network-aware footer banner. App-scoped so its default-network
    // callback (registered only while collected) lives for the process, not per-Activity.
    single<NetworkMonitor> {
        AndroidNetworkMonitor(
            context = app,
            scope = CoroutineScope(get<AppDispatchers>().default + SupervisorJob()),
        )
    }
    // Native customer-contact launches (dialer fallback + Google Maps navigation) for the nav card.
    single<CustomerContactLauncher> { AndroidCustomerContactLauncher(context = app) }
    // Step 7 outbox — Android SQLite driver factory (needs a Context).
    single { ShieldDbDriverFactory(app) }
    // Single-sourced Kavach assets — read from Flutter's flutter_assets (one copy in the APK, ECPO-916).
    // RemoteConfigGateway → the RC-overridable asset prefix (#2); AppDispatchers → off-main read.
    single<ShieldAssetReader> { AndroidShieldAssetReader(app, get(), get()) }
    // 2e deterrence — audio player needs a Context; bound here like the DB factory.
    single<DeterrenceAudioPlayer> {
        val reader = get<ShieldAssetReader>()
        AndroidDeterrenceAudioPlayer(app, get()) { reader.read(ShieldAssetReader.DETERRENCE_AUDIO) }
    }
    // In-progress job voice cues (half-time / T-10) — native MediaPlayer; reads the bundled localized
    // clip via the general ShieldAssetReader (flutter_assets), passed as a lambda so no kavach coupling.
    single<JobCueAudioPlayer> {
        val reader = get<ShieldAssetReader>()
        AndroidJobCueAudioPlayer(app, get(), get()) { path -> reader.read(path) }
    }
    // (d) device condition monitors — need a Context.
    single<BatteryMonitor> { AndroidBatteryMonitor(app) }
    single<StorageMonitor> { AndroidStorageMonitor(app) }
    // (e) connectivity factory — needs a Context.
    single { ConnectivityFactory(app) }
    single<ModelAssetResolver> {
        val reader = get<ShieldAssetReader>()
        AndroidModelAssetResolver(app, get()) { name -> reader.read("${ShieldAssetReader.ML_MODELS_DIR}/$name") }
    }
}
