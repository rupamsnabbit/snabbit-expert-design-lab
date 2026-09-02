package com.snabbit.runner

import com.clevertap.android.sdk.Application as CleverTapApplication
import com.snabbit.runner.kavach.kavachHostModule
import com.snabbit.runner.awol.AwolOverlaySpec
import com.google.android.gms.maps.MapsInitializer
import com.google.firebase.perf.FirebasePerformance
import com.snabbit.runner.kavach.kavachHostModule
import com.snabbit.runner.kmp_bridge.CrashReporterPlugin
import com.snabbit.runner.kmp_bridge.ProfileActionsPlugin
import com.snabbit.runner.kmp_bridge.RunnerStateCacheSeeder
import com.snabbit.runner.language.languageScreenAppModule
import com.snabbit.runner.debug.ChuckerDebug
import com.snabbit.runner.overlayhost.OverlayLauncher
import com.snabbit.runner.overlayhost.overlaySpecsModule
import com.snabbit.runner.shared.core.KmpBootstrap
import com.snabbit.runner.shared.core.alarm.AlarmController
import com.snabbit.runner.shared.core.analytics.AnalyticsConfig
import org.koin.core.context.loadKoinModules
import com.snabbit.runner.shared.features.awol.domain.AwolFlags
import com.snabbit.runner.shared.features.awol.presentation.AwolViewModel
import com.snabbit.runner.shared.features.profile.ProfileHostActions
import org.koin.core.context.GlobalContext
import org.koin.core.context.loadKoinModules
import org.koin.mp.KoinPlatform.getKoin
import org.koin.core.context.loadKoinModules

/**
 * App-level lifecycle owner.
 *
 * Subclasses CleverTap's [CleverTapApplication] so their SDK still
 * initializes (their docs require this exact class — or a subclass — to
 * be the manifest's `android:name`). On top of CleverTap's init we own
 * the KMP module bootstrap via [KmpBootstrap.initialize], which:
 *
 *  - Registers Tink crypto primitives (`AeadConfig.register`) — once
 *    per process, not in `TinkDataStoreEncryptedStore`'s constructor.
 *  - Starts Koin with the platform + core + language + analytics modules.
 *    Used to live inside `KmpBridgePlugin.registerWith`, which re-ran every
 *    time a `FlutterEngine` was created — fragile on engine recreation.
 *  - Hydrates persisted credentials on [kotlinx.coroutines.Dispatchers.IO]
 *    so DataStore disk reads never block the main thread.
 *  - Fires `provider.start()` for each registered analytics provider on
 *    [kotlinx.coroutines.Dispatchers.Main] (AppsFlyer wants the main
 *    looper, LLD §5.2).
 */
class SnabbitRunnerApplication : CleverTapApplication() {
    override fun onCreate() {
        super.onCreate()
        // Process-wide foreground signal, read on the FCM thread by SnabbitPushService
        // to decide whether an incoming new-job push draws over other apps (only when
        // backgrounded) or lets the in-app surface handle it (when foreground).
        registerActivityLifecycleCallbacks(AppForegroundTracker)
        // ponytail: pre-warm the Google Maps renderer once per process so the
        // first Map composable opens against a warm SDK instead of paying
        // cold-init on the UI thread. Idempotent — subsequent calls no-op.
        MapsInitializer.initialize(this, MapsInitializer.Renderer.LATEST) { /* no-op */ }
        // Firebase Performance trace around the KMP bootstrap. This is the only
        // main-thread work KMP does at launch — Tink registration, the Koin graph
        // (36 modules) and the Coil singleton — and it ran completely unmeasured:
        // all 17 existing traces are Dart-side, so a cold-start regression here was
        // invisible. Sub-phase durations arrive via onPhase below and are recorded as
        // trace metrics, so "cold start got worse" resolves to a named cause.
        //
        // runCatching + stop() in a finally: bootstrap is deliberately fail-open (a
        // failure must never break launch), so instrumenting it must not introduce a
        // way to crash. A missing or uninitialised Performance SDK degrades to no
        // trace, never to a failed launch.
        val bootstrapTrace = runCatching {
            FirebasePerformance.getInstance().newTrace(TRACE_KMP_BOOTSTRAP).apply { start() }
        }.getOrNull()
        try {
        KmpBootstrap.initialize(
            app = this,
            // Forwards every KMP-side report() call to the Dart
            // MonitoringServiceHelper.logError pipeline (→ Coralogix)
            // via CrashReporterPlugin's MethodChannel. No-ops to
            // Logcat for the brief window before MainActivity attaches
            // the plugin to a FlutterEngine.
            crashReporter = CrashReporterPlugin::report,
            analyticsConfig = AnalyticsConfig(
                // Injected at build time from local.properties / CI (see
                // app/build.gradle). Blank → that provider's registration is
                // skipped (AF / Mixpanel respectively).
                appsFlyerDevKey = BuildConfig.APPSFLYER_DEV_KEY,
                mixpanelProjectToken = BuildConfig.MIXPANEL_PROJECT_TOKEN,
                cleverTapEnabled = true,
                debugLogging = BuildConfig.DEBUG,
            ),
            // Debug-only: the Chucker interceptor module, registered WITH startKoin so it's present
            // before initialize's startup network calls build the lazy engine. Empty in release. #chucker
            extraModules = listOf(ChuckerDebug.networkModule(this)),
            // Phase timings become named trace metrics (ms), so Firebase reports
            // tink / koin / coil separately instead of one opaque total.
            onPhase = { phase, ms -> bootstrapTrace?.putMetric(phase, ms) },
        )
        } finally {
            // finally, not after the call: initialize() returns early on the Koin
            // re-entry guard and on a caught bootstrap failure, and a trace that is
            // never stopped is never reported at all.
            runCatching { bootstrapTrace?.stop() }
        }
        // Debug-only: single draggable network-inspector button over every Activity (Flutter + CMP);
        // tap opens the unified Chucker dashboard. No-op in release. #chucker
        ChuckerDebug.armFloatingButton(this)
        // `:app` screen mappings — only if Koin actually started. KmpBootstrap.initialize is fail-open;
        // if it caught an error before startKoin, an unconditional loadKoinModules → GlobalContext.get()
        // throws IllegalStateException uncaught in onCreate → the whole app crashes, defeating fail-open (#R-A).
        if (org.koin.core.context.GlobalContext.getOrNull() != null) {
            loadKoinModules(kavachHostModule)
        }
        // `:app` screen mappings for native destinations (after Koin is started).
        loadKoinModules(kavachHostModule)
        // Only if KMP/Koin actually started (KmpBootstrap fail-opens otherwise):
        // register the :app-only Language native screen (needs the Android
        // ProfileGatewayImpl/LanguageAnalyticsImpl seams) and bind the Profile host
        // actions — the two Flutter-channel actions + the debug-build flag the Profile
        // ViewModel reads via ProfileHostActions.
        if (GlobalContext.getOrNull() != null) {
            loadKoinModules(languageScreenAppModule)
            getKoin().get<ProfileHostActions>().bind(
                silentNotifications = ProfileActionsPlugin::silentNotifications,
                panCardUnavailable = ProfileActionsPlugin::panCardUnavailable,
                isDebug = BuildConfig.DEBUG,
            )
            // Alert-alarm silence seam: the AWOL / delayed-check-in acknowledge CTAs
            // stop the Flutter-owned alarm through here. Unbound it no-ops, so the
            // fail-open path above just leaves the pre-existing behaviour.
            getKoin().get<AlarmController>().bind(ProfileActionsPlugin::silenceAlarm)
        }
        // `:app` screen mappings — only if Koin actually started. KmpBootstrap.initialize is fail-open;
        // if it caught an error before startKoin, an unconditional loadKoinModules → GlobalContext.get()
        // throws IllegalStateException uncaught in onCreate → the whole app crashes, defeating fail-open (#R-A).
        if (org.koin.core.context.GlobalContext.getOrNull() != null) {
            loadKoinModules(kavachHostModule)
        }

        // App-side OverlaySpec registrations for ComposeOverlayHost. Guarded:
        // if the KMP bootstrap failed (fail-open contract above), Koin never
        // started and there is nothing to plug the specs into.
        val koin = GlobalContext.getOrNull() ?: return
        koin.loadModules(listOf(overlaySpecsModule))

        // Arm the Application-scoped overlay launcher (store-driven maybeLaunch;
        // NOT ActivityAware — the killed-state path needs it alive from process
        // start) and forward its app-visibility signal into the AWOL coordinator's
        // §9 surface routing (foreground / PiP inputs). The coordinator is
        // resolved FIRST so its store collector subscribes before the
        // launcher's — on any emission the routing state is at worst one
        // dispatch behind the launch decision, never a full envelope behind.
        val awolViewModel = koin.get<AwolViewModel>()
        // Seed the coordinator's flags from the launcher's persisted gate before
        // arming it: on an FCM-revived process the Dart config push never happens
        // (OverlayLauncherPlugin only attaches via MainActivity), so without this
        // the routing side would stay dark while the launcher gate is hydrated —
        // the two must agree on killed-state revivals too.
        awolViewModel.setFlags(
            AwolFlags(overlayEnabled = OverlayLauncher.persistedEnabled(this, AwolOverlaySpec.KEY)),
        )
        val launcher = OverlayLauncher.init(this)
        launcher.addVisibilityListener { foreground, inPip ->
            awolViewModel.setHostVisibility(isForeground = foreground, isInPip = inPip)
        }
        // Killed-state data feed: RunnerStatePlugin only attaches via MainActivity,
        // so on an FCM revival the store would stay empty and the armed launcher
        // would never fire. The bg push handler caches `current_state` to
        // SharedPreferences — seed the store from that write (and watch for it).
        RunnerStateCacheSeeder.arm(this, koin.get())
    }

    override fun onTerminate() {
        // Android only invokes onTerminate on emulators; on real devices
        // the OS just reaps the process. Still wired so test harnesses
        // and any future host that calls it explicitly release the Ktor
        // engine's thread/connection pools.
        KmpBootstrap.terminate()
        super.onTerminate()
    }

    private companion object {
        /** Firebase Performance custom trace: KMP's main-thread cost at launch. */
        const val TRACE_KMP_BOOTSTRAP = "kmp_bootstrap_init"
    }
}
