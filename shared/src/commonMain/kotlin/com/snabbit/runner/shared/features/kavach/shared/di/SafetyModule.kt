package com.snabbit.runner.shared.features.kavach.shared.di

import com.snabbit.runner.shared.core.connectivity.Connectivity
import com.snabbit.runner.shared.core.connectivity.ConnectivityFactory
import com.snabbit.runner.shared.core.defaultAppDispatchers
import com.snabbit.runner.shared.core.lifecycle.AppLifecycle
import com.snabbit.runner.shared.core.lifecycle.platformAppLifecycle
import com.snabbit.runner.shared.core.navigation.di.nativeDestination
import com.snabbit.runner.shared.core.network.defaultHttpClientEngine
import com.snabbit.runner.shared.features.kavach.shared.SafetyHome
import com.snabbit.runner.shared.features.kavach.sos.SosActive
import com.snabbit.runner.shared.features.kavach.shield.data.gateway.StoreCurrentStateGateway
import com.snabbit.runner.shared.features.kavach.shield.data.gateway.CurrentStateGateway
import com.snabbit.runner.shared.features.kavach.shield.data.store.JobIdCache
import com.snabbit.runner.shared.features.kavach.shared.data.ApiPreflight
import com.snabbit.runner.shared.features.kavach.shared.data.SafetyDataSource
import com.snabbit.runner.shared.features.kavach.shared.data.SafetyDataSourceImpl
import com.snabbit.runner.shared.features.kavach.shield.data.gateway.StoreShieldProfileGateway
import com.snabbit.runner.shared.features.kavach.shield.data.gateway.ShieldProfileGateway
import com.snabbit.runner.shared.features.kavach.shield.data.store.ShieldAssetReader
import com.snabbit.runner.shared.features.kavach.shield.data.remote.ShieldConsentApi
import com.snabbit.runner.shared.features.kavach.shield.data.remote.ShieldConsentApiImpl
import com.snabbit.runner.shared.features.kavach.shield.data.store.ShieldFileReader
import com.snabbit.runner.shared.features.kavach.shield.data.store.ShieldManualMonitoringStore
import com.snabbit.runner.shared.features.kavach.shield.data.upload.ShieldKeyWrapper
import com.snabbit.runner.shared.features.kavach.shield.data.upload.ShieldUploadApi
import com.snabbit.runner.shared.features.kavach.shield.data.upload.ShieldUploadApiImpl
import com.safetykavach.shield.recording.ClipStore
import com.snabbit.runner.shared.features.kavach.shield.data.upload.ShieldUploadQueue
import com.snabbit.runner.shared.features.kavach.shield.domain.upload.ShieldSyncScheduler
import com.snabbit.runner.shared.features.kavach.sos.data.remote.SosApi
import com.snabbit.runner.shared.features.kavach.sos.data.remote.SosApiImpl
import com.snabbit.runner.shared.features.kavach.sos.data.gateway.SosVisibilityGateway
import com.snabbit.runner.shared.features.kavach.sos.data.store.SosLiveStore
import com.snabbit.runner.shared.features.kavach.sos.data.store.SosPushStore
import com.snabbit.runner.shared.features.kavach.shield.data.db.ShieldDatabase
import com.snabbit.runner.shared.features.kavach.shield.data.db.ShieldDbDriverFactory
import com.snabbit.runner.shared.features.kavach.shield.data.store.platformShieldFileReader
import com.snabbit.runner.shared.features.kavach.sos.domain.deterrence.DeterrenceCoordinator
import com.snabbit.runner.shared.features.kavach.shield.domain.KavachPermissionGate
import com.snabbit.runner.shared.core.network.NetworkConfigStore
import com.snabbit.runner.shared.features.kavach.shield.domain.ShieldRcGates
import com.snabbit.runner.shared.features.kavach.shield.domain.ShieldInitLock
import com.snabbit.runner.shared.features.kavach.shield.domain.ShieldMlLoadGuard
import com.safetykavach.shield.core.model.MlLoadGuardPort
import com.snabbit.runner.shared.features.kavach.shield.domain.restore.ShieldEventRouter
import com.snabbit.runner.shared.features.kavach.shared.domain.JobKavachCoordinator
import com.snabbit.runner.shared.features.kavach.shared.domain.ActiveTriggerHolder
import com.snabbit.runner.shared.features.kavach.shared.domain.KavachConsentGate
import com.snabbit.runner.shared.features.kavach.shared.domain.SafetyForegroundReconciler
import com.snabbit.runner.shared.features.kavach.shield.domain.restore.ShieldLayerRestore
import com.snabbit.runner.shared.features.kavach.shield.domain.upload.ShieldUploadCoordinator
import com.snabbit.runner.shared.features.kavach.shield.domain.upload.ShieldUploadReconnectTrigger
import com.snabbit.runner.shared.features.kavach.sos.domain.SosCoordinator
import com.snabbit.runner.shared.features.kavach.sos.domain.SosPhase
import io.ktor.client.HttpClient
import org.koin.dsl.module

/**
 * Kavach feature Koin wiring (commonMain): the seam binding + native-destination
 * registrations. Screen mapping lives in the `:app` `kavachHostModule`.
 * Registered in `KmpBootstrap.initialize`.
 */
val safetyModule = module {
    // §10 host-context — Decision A resolved to the store-read path: reuse the in-memory current_state
    // + runners/me the app already keeps live (Dart poll / realtime / FCM), so kavach adds no network.
    // JobIdCache = the job the shield armed for; the arm sites latch it, the upload seam reads it.
    single { JobIdCache() }
    single<CurrentStateGateway> { StoreCurrentStateGateway(runnerStateStore = get()) }
    // profileStore via getOrNull: its binding (profileModule) isn't loaded on iOS → fail-closed defaults there.
    single<ShieldProfileGateway> { StoreShieldProfileGateway(profileStore = getOrNull()) }
    // Pre-flight shared by every runner-scoped SOS/shield call: no token → skip (never 401 → forced
    // logout); offline → skip. networkMonitor via getOrNull — no iOS binding, and an absent monitor
    // must not block calls.
    single { ApiPreflight(storeManager = get(), analytics = get(), networkMonitor = getOrNull()) }
    single<SosApi> { SosApiImpl(httpClient = get(), crashReporter = get(), preflight = get()) }
    // D-5: runner consent POST (hard gate before the engine starts).
    single<ShieldConsentApi> { ShieldConsentApiImpl(httpClient = get(), crashReporter = get(), preflight = get()) }
    // Home-page runner-consent gate (Flutter ShieldConsentProvider parity): decides show + records consent.
    single { KavachConsentGate(shieldProfile = get(), consentApi = get(), profileStore = getOrNull(), analytics = get()) }
    // Step 7: S3 PUT needs a raw, no-auth Ktor client — own (fresh) engine so it never
    // shares/closes the SnabbitHttpClient singleton engine. App-lifetime (not closed).
    single<ShieldUploadApi> { ShieldUploadApiImpl(httpClient = get(), s3Client = HttpClient(defaultHttpClientEngine()), crashReporter = get(), preflight = get()) }
    single {
        val reader = get<ShieldAssetReader>()
        ShieldKeyWrapper(pemProvider = { reader.read(ShieldAssetReader.UPLOAD_PUBLIC_KEY) })
    }
    single<ShieldFileReader> { platformShieldFileReader() }
    // Step 7 outbox: DB (driver from the platform ShieldDbDriverFactory) → queue → event coordinator.
    single { ShieldDatabase(get<ShieldDbDriverFactory>().create()) }
    single {
        ShieldUploadQueue(
            db = get(),
            uploadApi = get(),
            currentTimeMs = get(),
            analytics = get(),
            dispatchers = defaultAppDispatchers(),
            crashReporter = get(),
            // getOrNull: Android binds WorkManager; iOS has no out-of-band drain.
            syncScheduler = getOrNull<ShieldSyncScheduler>(),
        )
    }
    // Eager so init runs at launch: attaches the EncryptedAudio collector + flushes the backlog.
    single(createdAtStart = true) {
        val sos = get<SosCoordinator>()
        val jobIdCache = get<JobIdCache>()
        ShieldUploadCoordinator(
            shield = get(),
            queue = get(),
            keyWrapper = get(),
            fileReader = get(),
            remoteConfig = get(),
            // The arm sites latch JobIdCache; this sync seam reads it.
            currentJobId = { jobIdCache.get() },
            isSos = { sos.state.value.phase != SosPhase.IDLE },
            analytics = get(),
            dispatchers = defaultAppDispatchers(),
            crashReporter = get(),
            // getOrNull: the plugin binds this on Android; absent → no sweep.
            clipStore = getOrNull<ClipStore>(),
        )
    }
    // Shared active-trigger SSOT (Flutter's ShieldStartStopController.activeTrigger): arm/SOS write it,
    // the lifecycle-analytics emitters read it. One single so the three consumers share one value.
    single { ActiveTriggerHolder() }
    // Shared lock serializing plugin init across arm() + ShieldLayerRestore.restore() (no double-init).
    single { ShieldInitLock() }
    single { SosCoordinator(shield = get(), sosApi = get(), remoteConfig = get(), lifecycle = get(), currentState = get(), analytics = get(), dispatchers = defaultAppDispatchers(), activeTrigger = get(), sosLiveStore = get<SosLiveStore>(), preflight = get<ApiPreflight>()) }
    // Step 9: plugin signals → product analytics. Eager so it collects from app launch
    // (self-starts in init; 2b lifecycle hoist will unify start() across the coordinators).
    single(createdAtStart = true) { ShieldEventRouter(shield = get(), analytics = get(), dispatchers = defaultAppDispatchers(), activeTrigger = get()) }
    // §16 lifecycle: app-wide foreground source (core seam; movable to a core module when a 2nd
    // consumer appears) + the foreground→/sos/active reconcile trigger (eager so it observes launch).
    single<AppLifecycle> { platformAppLifecycle() }
    single { SosPushStore(store = get()) }
    // Persisted "SOS may still be open" marker — the reason gate for the foreground reconcile.
    single { SosLiveStore(store = get()) }
    // Backend-driven SOS button visibility (Flutter partner_home parity) — consumed by Home + Job.
    single { SosVisibilityGateway(runnerStateStore = get(), dispatchers = defaultAppDispatchers()) }
    // Persists the manually-activated jobId so a manual recording survives resume within the same job.
    single { ShieldManualMonitoringStore(store = get()) }
    // 2f app-driven permission gate (mic / mic+location) over the shipped PermissionManager seam.
    single { KavachPermissionGate(permissions = get()) }
    // RC cohort kill-switches for the monitoring/recording tiers — read the generic Firebase RC port
    // (Android native; iOS defaults → fail-closed OFF). Flutter ShieldRcGates parity.
    single { ShieldRcGates(get()) }
    // Version-keyed guard for the uncatchable native ML load-crash: after a crash it keeps ML off for
    // this build (recording/accel/SOS unaffected) until a new build. appVersion = x-version-code.
    single {
        val ncs = get<NetworkConfigStore>()
        ShieldMlLoadGuard(prefs = get(), appVersion = { ncs.snapshot()?.versionCode ?: "" })
    }
    // Same guard instance handed to the plugin as its lazy-load crash-guard port.
    single<MlLoadGuardPort> { get<ShieldMlLoadGuard>() }
    // §16 restore — expected-layer restore on foreground.
    single { ShieldLayerRestore(shield = get(), currentState = get(), shieldProfile = get(), manualStore = get(), remoteConfig = get(), modelAssets = get(), rcGates = get(), analytics = get(), initLock = get(), mlGuard = get(), realtimeConfig = getOrNull(), activeTrigger = get(), jobIdCache = get()) }
    single(createdAtStart = true) { SafetyForegroundReconciler(lifecycle = get(), sosCoordinator = get(), pushStore = get(), sosLiveStore = get(), layerRestore = get(), crashReporter = get(), dispatchers = defaultAppDispatchers()) }
    // Job ↔ Kavach lifecycle: launch on in-progress (mandatory mic gate → gated + auto-aware start),
    // tear down on checkout/end.
    single(createdAtStart = true) { JobKavachCoordinator(runnerState = get(), safety = get(), permissionGate = get(), lifecycle = get(), dispatchers = defaultAppDispatchers(), analytics = get(), realtimeConfig = getOrNull()) }
    // 2e deterrence — plays the clip on SOS-active; audio seam from the platform module.
    single(createdAtStart = true) { DeterrenceCoordinator(sos = get(), audioPlayer = get(), remoteConfig = get(), analytics = get(), dispatchers = defaultAppDispatchers()) }
    // (e) connectivity — drain the upload outbox on each offline→online edge.
    single<Connectivity> { get<ConnectivityFactory>().create() }
    single(createdAtStart = true) {
        val queue = get<ShieldUploadQueue>()
        ShieldUploadReconnectTrigger(connectivity = get(), drain = { queue.processQueue() }, dispatchers = defaultAppDispatchers())
    }
    single<SafetyDataSource> {
        SafetyDataSourceImpl(
            shield = get(), remoteConfig = get(), modelAssets = get(), sosApi = get(), consentApi = get(),
            currentState = get(), shieldProfile = get(), manualStore = get(), prefs = get(), battery = get(), storage = get(), analytics = get(),
            rcGates = get(), mlGuard = get(), activeTrigger = get(), initLock = get(), jobIdCache = get(),
            syncScheduler = getOrNull<ShieldSyncScheduler>(),
        )
    }
    nativeDestination<SafetyHome>(key = "kavach_home") { SafetyHome }
    nativeDestination<SosActive>(key = "kavach_sos_active") { SosActive }
}
