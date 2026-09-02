package com.snabbit.runner.shared.core

import android.app.Application
import android.content.pm.ApplicationInfo
import android.os.SystemClock
import android.util.Log
import coil3.SingletonImageLoader
import com.google.crypto.tink.aead.AeadConfig
import com.snabbit.runner.shared.core.analytics.AnalyticsConfig
import com.snabbit.runner.shared.core.analytics.AnalyticsTrackerImpl
import com.snabbit.runner.shared.core.analytics.di.analyticsAndroidModule
import com.snabbit.runner.shared.core.analytics.di.analyticsModule
import com.snabbit.runner.shared.core.camera.di.cameraKoinModule
import com.snabbit.runner.shared.core.config.RemoteConfigGateway
import com.snabbit.runner.shared.core.designsystem.initSnabbitImageLoader
import com.snabbit.runner.shared.core.di.coreModule
import com.snabbit.runner.shared.core.di.platformModule
import com.snabbit.runner.shared.core.image.buildSnabbitImageLoader
import com.snabbit.runner.shared.core.network.defaultHttpClientEngine
import com.snabbit.runner.shared.core.location.di.locationModule
import com.snabbit.runner.shared.core.navigation.di.navigationModule
import com.snabbit.runner.shared.core.permissions.di.permissionsModule
import com.snabbit.runner.shared.core.realtime.realtimeModule
import com.snabbit.runner.shared.core.remoteconfig.di.remoteConfigModule
import com.snabbit.runner.shared.features.awol.di.awolModule
import com.snabbit.runner.shared.features.blocklist.di.blockListModule
import com.snabbit.runner.shared.core.localization.LocalizationStore
import com.snabbit.runner.shared.core.network.NetworkConfigStore
import com.snabbit.runner.shared.core.network.NetworkTuningStore
import com.snabbit.runner.shared.core.storage.StoreManager
import com.snabbit.runner.shared.features.job.delayedcheckin.di.delayedCheckinModule
import com.snabbit.runner.shared.features.job.di.jobModule
import com.snabbit.runner.shared.features.blocklist.di.blockListModule
import com.snabbit.runner.shared.features.bottomnav.bottomNavScreenModule
import com.snabbit.runner.shared.features.bottomnav.di.bottomNavModule
import com.snabbit.runner.shared.features.gamification.di.gamificationModule
import com.snabbit.runner.shared.features.autoot.di.autoOtModule
import com.snabbit.runner.shared.features.home.di.homeModule
import com.snabbit.runner.shared.features.home.banners.di.bannerModule
import com.snabbit.runner.shared.features.home.seeyoutomorrow.di.seeYouTomorrowModule
import com.snabbit.runner.shared.features.home.suspended.di.suspendedModule
import com.snabbit.runner.shared.features.periodleave.di.periodLeaveModule
import com.snabbit.runner.shared.features.seva.di.sevaModule
import com.snabbit.runner.shared.features.shift.attendance.di.attendanceModule
import com.snabbit.runner.shared.features.shift.core.di.shiftModule
import com.snabbit.runner.shared.features.shift.presentation.login.shiftLoginScreenModule
import com.snabbit.runner.shared.features.support.di.supportModule
import com.snabbit.runner.shared.features.language.di.languageModule
import com.snabbit.runner.shared.features.kavach.shared.di.safetyModule
import com.safetykavach.shield.di.shieldAndroidModules
import com.snabbit.runner.shared.storage.di.storageModule
import com.snabbit.runner.shared.features.loan.di.loanModule
import com.snabbit.runner.shared.features.pan.di.panModule
import com.snabbit.runner.shared.features.profile.di.profileModule
import com.snabbit.runner.shared.features.profile.di.profileAndroidModule
import com.snabbit.runner.shared.features.kavach.shared.di.safetyAndroidModule
import com.snabbit.runner.shared.features.tiering.di.tieringModule
import com.safetykavach.shield.di.shieldAndroidModules
import io.ktor.client.engine.HttpClientEngine
import kotlinx.coroutines.CoroutineExceptionHandler
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.koin.android.ext.koin.androidContext
import org.koin.core.context.GlobalContext
import org.koin.core.context.startKoin
import org.koin.core.module.Module
import org.koin.mp.KoinPlatform.getKoin

/**
 * Single entry point the Android host calls from `Application.onCreate`
 * to stand up the KMP module. Keeps Tink + Koin-Android deps internal to
 * `:shared` — `:app` doesn't need to know about them.
 *
 * Steps:
 *  1. [AeadConfig.register] — app-lifecycle Tink crypto primitive init.
 *  2. [startKoin] with [platformModule] + [coreModule] +
 *     [analyticsModule] + [analyticsAndroidModule], wiring the Android
 *     [Application] context via `androidContext()`.
 *  3. Kick off [StoreManager.hydrateAll] on [Dispatchers.IO] so persisted
 *     credentials are restored without blocking the main thread.
 *  4. Kick off [AnalyticsTrackerImpl.bootstrap] on [Dispatchers.Main]
 *     (AppsFlyer posts internal work to the main looper, §5.2). The
 *     coroutine is fire-and-forget — `Application.onCreate` does not
 *     wait for AF init to finish.
 *
 * Idempotent-ish: calling twice will re-run `AeadConfig.register` (Tink
 * tolerates that) but `startKoin` will throw. Hosts must call exactly
 * once per process.
 */
object KmpBootstrap {

    /** The image loader's HTTP engine — a second engine, distinct from the
     *  Koin-bound API one; retained so [terminate] can close it too. */
    @Volatile
    private var imageEngine: HttpClientEngine? = null

    fun initialize(
        app: Application,
        crashReporter: ((Throwable, Map<String, String>) -> Unit)? = null,
        analyticsConfig: AnalyticsConfig = AnalyticsConfig.DISABLED,
        // Extra Koin modules registered WITH startKoin — before any startup network call builds the
        // lazy HttpClientEngine — e.g. the debug Chucker interceptor. Empty in release.
        extraModules: List<Module> = emptyList(),
        /**
         * Optional main-thread phase timings, in milliseconds, for the host to record.
         * Invoked as `(phase, durationMs)` for each blocking step below.
         *
         * A callback rather than a direct Firebase Performance call so `:shared` keeps
         * no dependency on it and `commonMain` stays platform-clean — the host owns the
         * reporting sink. Never invoked for the fire-and-forget IO work further down,
         * which does not block launch.
         */
        onPhase: ((String, Long) -> Unit)? = null,
    ) {
        // elapsedRealtime, not currentTimeMillis: immune to wall-clock adjustments,
        // which would otherwise produce negative or wildly inflated launch timings.
        fun <T> timed(phase: String, block: () -> T): T {
            if (onPhase == null) return block()
            val started = SystemClock.elapsedRealtime()
            return try {
                block()
            } finally {
                onPhase(phase, SystemClock.elapsedRealtime() - started)
            }
        }
        // FIRST, before anything can log: release-gate Logger.d so debug diagnostics
        // (request URLs with job/penalty ids, capture tokens, saved file paths) never
        // reach logcat on a shipped build. Warn/error keep writing — crash triage needs
        // them. Derived from the host's manifest `debuggable` flag, which is the same
        // signal as `BuildConfig.DEBUG` but readable off the Application we already
        // hold, so no new host parameter and no `:app` change. Armed above the re-entry
        // guard so a second call still leaves the gate correct.
        DebugLogGate.arm((app.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0)
        // Single-process app → called once. Guard explicitly so the intent is in
        // code, not inferred from the manifest (startKoin throws on re-entry).
        if (GlobalContext.getOrNull() != null) return
        try {
            timed("tink") { AeadConfig.register() }
            // Coil singleton behind core/image RemoteImage — installed before
            // any composition exists. setSafe is a no-op if a factory is
            // already set, and the factory itself runs lazily on first load.
            SingletonImageLoader.setSafe { context ->
                // Retain the engine so terminate() can close it — it is a second
                // engine, separate from the Koin-bound API one.
                val engine = defaultHttpClientEngine().also { imageEngine = it }
                buildSnabbitImageLoader(context, engine)
            }
            timed("koin") {
            startKoin {
                androidContext(app)
                modules(
                    platformModule(app, crashReporter),
                    coreModule,
                    navigationModule,
                    bottomNavModule,
                    bottomNavScreenModule,
                    remoteConfigModule,
                    languageModule,
                    realtimeModule,
                    attendanceModule,
                    shiftModule,
                    shiftLoginScreenModule,
                    sevaModule,
                    periodLeaveModule,
                    gamificationModule,
                    homeModule,
                    autoOtModule,
                    suspendedModule,
                    seeYouTomorrowModule,
                    bannerModule,
                    jobModule,
                    supportModule,
                    blockListModule,
                    storageModule(app),
                    profileModule,
                    profileAndroidModule,
                    loanModule,
                    panModule,
                    tieringModule,
                    permissionsModule(),
                    locationModule(),
                    safetyModule,
                    safetyAndroidModule,
                    delayedCheckinModule,
                    awolModule,
                    cameraKoinModule,
                    analyticsModule,
                    analyticsAndroidModule(app, analyticsConfig),
                )
                // Kavach safety-shield engine — shared logic + Android seam impls
                // (FGS/audio/sensors/ML/encryption/notifications/permissions),
                // consumed via the composite build. Resolves against androidContext.
                modules(shieldAndroidModules())
                if (extraModules.isNotEmpty()) modules(extraModules)
            }
            }
        } catch (t: Throwable) {
            // Fail-open: a bootstrap failure must NEVER crash app launch. Report
            // and bail — the hydrate below needs a started Koin. (Network is live
            // on this branch, so failures here now route through crashReporter.)
            Log.e(TAG, "KMP bootstrap failed; KMP disabled for this process", t)
            crashReporter?.invoke(t, mapOf("op" to "kmpBootstrap"))
            return
        }
        // Register the Coil singleton ImageLoader (Ktor fetcher + memory/disk cache)
        // so network images like the Profile photo load — KMP's cached_network_image.
        // Covers the branch's disposition-sheet server-driven option icons too.
        timed("coil") { initSnabbitImageLoader() }
        // Surface hydrate failures (corrupt DataStore, Tink key issue, etc.)
        // — without this the SupervisorJob silently eats the throwable and
        // the token MutableStateFlow stays null forever, meaning every KMP
        // HTTP request goes out without auth headers with no diagnostic
        // trail.
        val hydrateHandler = CoroutineExceptionHandler { _, throwable ->
            getKoin().get<Logger>().e(TAG, "hydrateAll failed", throwable)
            crashReporter?.invoke(throwable, mapOf("op" to "hydrateAll"))
        }
        CoroutineScope(SupervisorJob() + Dispatchers.IO + hydrateHandler).launch {
            getKoin().get<StoreManager>().hydrateAll()
            // Cold-start network seed (Phase B): restore the last-persisted
            // baseUrl so KMP HTTP works on a force-killed FCM wake, before the
            // Flutter engine attaches and Dart pushes a fresh config.
            getKoin().get<NetworkConfigStore>().seedFromCache()
            // Cold-start localization seed: restore the last-persisted i18n map
            // so a KMP surface on a force-killed FCM wake shows the last-known
            // localized copy instead of English, before Dart re-pushes.
            getKoin().get<LocalizationStore>().seedFromCache()
        }

        // Refresh Firebase RC natively at launch — fire-and-forget on IO, independent of hydration.
        // The Flutter host also fetches every launch on the same process-wide singleton, so this is a
        // cheap redundant refresh.
        //
        // Mirror of hydrateHandler: fetchAndActivate()'s "never throws" covers the Task callback only.
        // firebase-config is compileOnly (host-provided), so acquiring the SDK handle can still throw
        // synchronously — SupervisorJob does not absorb that, it reaches the default uncaught handler.
        // Report rather than swallow: read() already falls back to defaults per key, so a dead gateway
        // is indistinguishable from "all flags at default" and would otherwise never surface.
        val remoteConfigHandler = CoroutineExceptionHandler { _, throwable ->
            getKoin().get<Logger>().e(TAG, "remote config fetchAndActivate failed", throwable)
            crashReporter?.invoke(throwable, mapOf("op" to "remoteConfigFetch"))
        }
        CoroutineScope(SupervisorJob() + Dispatchers.IO + remoteConfigHandler).launch {
            val rc = getKoin().get<RemoteConfigGateway>()
            rc.fetchAndActivate()
            // AFTER the activate, so the process's first HTTP call already sees the
            // fresh budget. Runs regardless of the return value — false only means
            // "nothing changed", and the previously activated values still need
            // reading into the store. If fetchAndActivate throws (dead SDK), the
            // handler above reports it and the store keeps its shipped defaults.
            getKoin().get<NetworkTuningStore>().refresh(rc)
        }

        // Analytics bootstrap. Fire-and-forget on Main — AF init runs in
        // ~20-80 ms; there is no timeout (LLD §5.9 / §8.1). If
        // getAll<AnalyticsProvider>() is empty (no dev key configured),
        // bootstrap() loops zero times and returns.
        //
        // After bootstrap, manually fire `app_launched`. AF's automatic
        // session tracking via ActivityLifecycleCallbacks misses the
        // first MainActivity.onStart because start() registers the
        // callbacks asynchronously (PR #361 launch-event bug). The
        // KMP-side AnalyticsRouteTable routes `app_launched` to AppsFlyer
        // (see AnalyticsRoutesConfig.SEED), so AF receives it regardless
        // of lifecycle timing. NOTE: `app_launched` must stay in the route
        // table or routing would drop it from AppsFlyer.
        //
        // Mirror of hydrateHandler: this coroutine runs on the main thread
        // at launch, so an uncaught throw — Koin resolution of
        // AnalyticsTrackerImpl, or logger/crashReporter throwing inside
        // bootstrap()'s own catch — would reach the default uncaught handler
        // and crash app launch, violating the fail-open contract above.
        // Catch, log, and report instead.
        val analyticsHandler = CoroutineExceptionHandler { _, throwable ->
            getKoin().get<Logger>().e(TAG, "analytics bootstrap failed", throwable)
            crashReporter?.invoke(throwable, mapOf("op" to "analyticsBootstrap"))
        }
        CoroutineScope(SupervisorJob() + Dispatchers.Main + analyticsHandler).launch {
            val tracker = getKoin().get<AnalyticsTrackerImpl>()
            tracker.bootstrap()
            tracker.track("app_launched", appLaunchedProps(app))
        }
    }

    /**
     * `app_launched` props (expert-v2 dictionary). Now routes to Mixpanel + CleverTap
     * (+ AppsFlyer) — see `AnalyticsRoutesConfig`. Best-effort: `is_logged_in` reads the
     * in-memory token snapshot (may be 0 if read before cold-start hydration completes);
     * `launch_source` defaults to `app_icon` (push/deeplink attribution deferred);
     * `session_id` is minted per launch. `app_killed` (swipe-away) is NOT shipped — the
     * only always-on service that survives task-removal is the Flutter
     * `flutter_background_service`, so a reliable kill event needs a Dart hook (out of
     * KMP scope); our native `OverlayService` runs only during an AWOL breach.
     *
     * Runs on [AppDispatchers.io]: the first `getSharedPreferences`/`getBoolean` on this
     * prefs file is a synchronous disk load, which must not happen on the main-thread
     * launch coroutine (StrictMode disk-read / launch jank).
     */
    private suspend fun appLaunchedProps(app: Application): Map<String, Any?> =
        withContext(getKoin().get<AppDispatchers>().io) {
            val prefs = app.getSharedPreferences("snabbit_session_analytics", android.content.Context.MODE_PRIVATE)
            val firstLaunch = !prefs.getBoolean("launched_before", false)
            if (firstLaunch) prefs.edit().putBoolean("launched_before", true).apply()
            val loggedIn = runCatching { getKoin().get<StoreManager>().tokenSnapshot() != null }.getOrDefault(false)
            val appVersion = runCatching { getKoin().get<NetworkConfigStore>().snapshot()?.appVersion }.getOrNull().orEmpty()
            mapOf(
                "session_id" to java.util.UUID.randomUUID().toString(),
                "app_version" to appVersion,
                "os_version" to (android.os.Build.VERSION.RELEASE ?: "unknown"),
                "is_logged_in" to if (loggedIn) 1 else 0,
                "is_first_launch" to if (firstLaunch) 1 else 0,
                "launch_source" to "app_icon",
            )
        }

    /**
     * Releases process-wide resources the KMP module owns. Idempotent —
     * resolves engine via Koin (so this is a no-op if Koin was never
     * started) and runCatching guards against double-close.
     *
     * Caller wires this to `Application.onTerminate()`. Note that
     * `onTerminate()` is documented as emulator-only by Android, so on
     * production devices this won't run on natural process death — the
     * value here is correctness in tests + Robolectric and explicit
     * documentation of the lifecycle contract.
     */
    fun terminate() {
        runCatching { getKoin().get<HttpClientEngine>().close() }
        runCatching { imageEngine?.close() }
        imageEngine = null
    }

    private const val TAG = "KmpBootstrap"
}
