package com.snabbit.runner.shared.core.di

import com.snabbit.runner.shared.core.AppDispatchers
import com.snabbit.runner.shared.core.CrashReporter
import com.snabbit.runner.shared.core.CurrentTimeMs
import com.snabbit.runner.shared.core.Logger
import com.snabbit.runner.shared.core.NowIso
import com.snabbit.runner.shared.core.analytics.AnalyticsConfig
import com.snabbit.runner.shared.core.connectivity.ConnectivityFactory
import com.snabbit.runner.shared.core.defaultAppDispatchers
import com.snabbit.runner.shared.core.defaultLogger
import com.snabbit.runner.shared.core.device.BatteryMonitor
import com.snabbit.runner.shared.core.device.IosBatteryMonitor
import com.snabbit.runner.shared.core.device.IosStorageMonitor
import com.snabbit.runner.shared.core.device.StorageMonitor
import com.snabbit.runner.shared.core.network.defaultHttpClientEngine
import com.snabbit.runner.shared.core.storage.EncryptedStore
import com.snabbit.runner.shared.core.storage.KeychainEncryptedStore
import com.snabbit.runner.shared.features.kavach.shield.data.store.IosModelAssetResolver
import com.snabbit.runner.shared.features.kavach.shield.data.store.ModelAssetResolver
import com.snabbit.runner.shared.features.kavach.shield.data.store.ShieldAssetReader
import com.snabbit.runner.shared.features.kavach.shield.data.store.iosShieldAssetReader
import com.snabbit.runner.shared.features.kavach.shield.data.db.ShieldDbDriverFactory
import com.snabbit.runner.shared.features.job.domain.audio.IosJobCueAudioPlayer
import com.snabbit.runner.shared.features.job.domain.audio.JobCueAudioPlayer
import com.snabbit.runner.shared.features.kavach.sos.domain.deterrence.DeterrenceAudioPlayer
import com.snabbit.runner.shared.features.kavach.sos.domain.deterrence.IosDeterrenceAudioPlayer
import io.ktor.client.engine.HttpClientEngine
import org.koin.dsl.module
import platform.Foundation.NSDate
import platform.Foundation.NSISO8601DateFormatter
import platform.Foundation.timeIntervalSince1970

/**
 * iOS-side bindings for [coreModule] (mirrors the Android `platformModule`). No `Application` —
 * the platform seams are context-free on iOS. Analytics is bound DISABLED (no iOS provider SDKs
 * yet — the fan-out is a no-op). `EncryptedStore` = native Keychain.
 */
fun platformModule(
    crashReporter: ((Throwable, Map<String, String>) -> Unit)? = null,
) = module {
    single<Logger> { defaultLogger() }
    single<AppDispatchers> { defaultAppDispatchers() }
    single<CrashReporter> {
        val log = get<Logger>()
        CrashReporter { t, m ->
            crashReporter?.invoke(t, m) ?: log.w("CrashReporter", "not configured; dropping: ${t.message}", t)
        }
    }
    single<EncryptedStore> { KeychainEncryptedStore(service = KEYCHAIN_SERVICE) }
    single<HttpClientEngine>(createdAtStart = false) { defaultHttpClientEngine() }
    single<CurrentTimeMs> { CurrentTimeMs { (NSDate().timeIntervalSince1970 * 1000.0).toLong() } }
    single<NowIso> { NowIso { NSISO8601DateFormatter().stringFromDate(NSDate()) } }
    single { ShieldDbDriverFactory() }
    // Single-sourced Kavach assets — read from Flutter's flutter_assets via the host provider (ECPO-916).
    single<ShieldAssetReader> { iosShieldAssetReader(get()) }
    single<DeterrenceAudioPlayer> {
        val reader = get<ShieldAssetReader>()
        IosDeterrenceAudioPlayer { reader.read(ShieldAssetReader.DETERRENCE_AUDIO) }
    }
    // In-progress job voice cues (half-time / T-10) — native AVAudioPlayer; reads the bundled localized
    // clip via the general ShieldAssetReader (host-injected provider), passed as a lambda (no kavach coupling).
    single<JobCueAudioPlayer> {
        val reader = get<ShieldAssetReader>()
        IosJobCueAudioPlayer(get()) { path -> reader.read(path) }
    }
    single<BatteryMonitor> { IosBatteryMonitor() }
    single<StorageMonitor> { IosStorageMonitor() }
    single { ConnectivityFactory() }
    single<ModelAssetResolver> {
        val reader = get<ShieldAssetReader>()
        IosModelAssetResolver(get()) { name -> reader.read("${ShieldAssetReader.ML_MODELS_DIR}/$name") }
    }
    // Analytics config — DISABLED on iOS until provider SDKs land (analyticsModule fan-out is a no-op).
    single { AnalyticsConfig.DISABLED }
}

private const val KEYCHAIN_SERVICE = "com.snabbit.runner.kmp"
