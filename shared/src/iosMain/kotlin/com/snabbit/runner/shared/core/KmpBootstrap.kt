package com.snabbit.runner.shared.core

import com.safetykavach.shield.detection.AudioClassifier
import com.safetykavach.shield.detection.VoiceDetector
import com.safetykavach.shield.di.shieldIosModules
import com.snabbit.runner.shared.core.analytics.di.analyticsModule
import com.snabbit.runner.shared.core.config.IosRemoteConfigProvider
import com.snabbit.runner.shared.core.config.RemoteConfigGateway
import com.snabbit.runner.shared.core.config.setIosRemoteConfigProvider
import com.snabbit.runner.shared.core.network.NetworkTuningStore
import com.snabbit.runner.shared.features.kavach.shield.data.store.IosFlutterAssetProvider
import com.snabbit.runner.shared.features.kavach.shield.data.store.setIosFlutterAssetProvider
import com.snabbit.runner.shared.core.di.coreModule
import com.snabbit.runner.shared.core.di.platformModule
import com.snabbit.runner.shared.core.location.di.locationModule
import com.snabbit.runner.shared.core.navigation.di.navigationModule
import com.snabbit.runner.shared.core.permissions.di.permissionsModule
import com.snabbit.runner.shared.core.storage.StoreManager
import com.snabbit.runner.shared.features.kavach.shared.di.safetyModule
import com.snabbit.runner.shared.features.language.di.languageModule
import io.ktor.client.engine.HttpClientEngine
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import org.koin.core.Koin
import org.koin.core.context.startKoin
import org.koin.core.context.stopKoin
import org.koin.dsl.module
import org.koin.mp.KoinPlatform

/**
 * iOS KMP bootstrap — the Swift host calls [initialize] once at launch (mirrors the Android
 * `KmpBootstrap`, without an `Application`). Fail-open: a bootstrap failure reports and bails.
 * Then hydrates persisted credentials (Keychain) off the main thread.
 *
 * D-17 resolved: the shield detection pipeline's host seams — [VoiceDetector] and [AudioClassifier]
 * (Silero VAD / YAMNet, implemented in Swift) — are passed in by the host and bound here Kotlin-side.
 * Per Koin's KMP guidance the host supplies the impls; Kotlin builds the module (Swift never touches
 * the Koin DSL). The host also supplies the Remote Config reader ([IosRemoteConfigProvider], Swift over
 * FIRRemoteConfig) the same way. Called from Swift as
 * `KmpBootstrap.shared.initialize(voiceDetector:audioClassifier:remoteConfig:flutterAssets:crashReporter:)`
 * — `flutterAssets` is optional; pass `FlutterShieldAssetProvider()` to enable iOS asset reads (absent → off).
 */
object KmpBootstrap {
    fun initialize(
        voiceDetector: VoiceDetector,
        audioClassifier: AudioClassifier,
        remoteConfig: IosRemoteConfigProvider,
        // Nullable default: a not-yet-updated AppDelegate omitting this must NOT be a Swift compile break.
        // Null → no provider set → the iOS reader yields empty bytes → ML/clip/Lottie off (graceful,
        // non-fatal) until the host wires FlutterShieldAssetProvider(). ECPO-916.
        flutterAssets: IosFlutterAssetProvider? = null,
        crashReporter: ((Throwable, Map<String, String>) -> Unit)? = null,
    ) {
        if (koinOrNull() != null) return
        // Host-provided RC reader (Swift / FIRRemoteConfig) → served by coreModule's remoteConfigGateway().
        setIosRemoteConfigProvider(remoteConfig)
        // Host-provided Flutter-asset reader (Swift / lookupKey(forAsset:)) → the single-sourced
        // ShieldAssetReader (ECPO-916). Only when supplied — absent leaves the reader on its empty-bytes path.
        flutterAssets?.let { setIosFlutterAssetProvider(it) }
        try {
            startKoin {
                modules(
                    platformModule(crashReporter),
                    coreModule,
                    navigationModule,
                    permissionsModule(),
                    locationModule(),
                    languageModule,
                    safetyModule,
                    analyticsModule,
                )
                modules(shieldIosModules())
                modules(hostDetectorModule(voiceDetector, audioClassifier))
            }
        } catch (t: Throwable) {
            crashReporter?.invoke(t, mapOf("op" to "kmpBootstrap"))
            return
        }
        val koin = KoinPlatform.getKoin()
        CoroutineScope(koin.get<AppDispatchers>().io).launch {
            runCatching { koin.get<StoreManager>().hydrateAll() }
                .onFailure { crashReporter?.invoke(it, mapOf("op" to "hydrateAll")) }
        }
        // Refresh Firebase RC natively at launch — fire-and-forget, fail-safe (any error → false, never
        // throws), independent of hydration. The host also fetches every launch on the same singleton.
        CoroutineScope(koin.get<AppDispatchers>().io).launch {
            runCatching {
                val rc = koin.get<RemoteConfigGateway>()
                rc.fetchAndActivate()
                // Mirrors Android: read the activated values into the app-wide HTTP
                // timeout store after the fetch, so the first call of the process uses
                // them. With no host provider wired this resolves to the shipped
                // defaults, which is exactly the pre-RC behaviour.
                koin.get<NetworkTuningStore>().refresh(rc)
            }.onFailure { crashReporter?.invoke(it, mapOf("op" to "remoteConfigFetch")) }
        }
    }

    fun terminate() {
        koinOrNull()?.let {
            runCatching { it.get<HttpClientEngine>().close() }
            stopKoin()
        }
    }

    private fun koinOrNull(): Koin? = runCatching { KoinPlatform.getKoin() }.getOrNull()

    // Host-provided detector impls (Swift) bound into the shield graph — the D-17 seam.
    private fun hostDetectorModule(voice: VoiceDetector, audio: AudioClassifier) = module {
        single<VoiceDetector> { voice }
        single<AudioClassifier> { audio }
    }
}
