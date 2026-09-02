package com.snabbit.runner.kmp_bridge

import android.app.Activity
import android.content.Intent
import android.provider.Settings
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.LifecycleOwner
import com.snabbit.runner.AppForegroundTracker
import com.snabbit.runner.awol.AwolOverlaySpec
import com.snabbit.runner.job.JobScreenExtras
import com.snabbit.runner.navigation.NavigationHostActivity
import com.snabbit.runner.shared.core.navigation.NavigationController
import com.snabbit.runner.shared.core.remoteconfig.RemoteConfigGateway
import com.snabbit.runner.shared.core.runnerstate.RunnerStateStore
import com.snabbit.runner.shared.core.session.RunnerSessionStore
import com.snabbit.runner.shared.features.job.data.JobServiceIdHolder
import com.snabbit.runner.job.overlay.NewJobOverlaySpec
import com.snabbit.runner.overlayhost.ComposeOverlayHost
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import org.koin.core.component.KoinComponent
import org.koin.core.component.inject

/**
 * Routes the KMP-hosted job stages — `RUNNER_NEW_JOB` → `RUNNER_JOB_POST_ACCEPT` /
 * `RUNNER_JOB_CHECK_IN` → `RUNNER_JOB_IN_PROGRESS` → `RUNNER_POST_CHECKOUT` — to a native
 * surface, driven by the existing state-flow engine ([RunnerStateStore], fed by
 * [RunnerStatePlugin] from Dart polling), NOT by a Dart launch call. Sits *beside* the bridge
 * plugin so that one stays a pure read/write channel.
 *
 * Surfaces:
 *  - **Foreground** (app visible — any Activity STARTED, per [AppForegroundTracker]): bring the
 *    native bottom-nav host ([NavigationHostActivity]) to front — its `ActiveJobOverlay` draws the
 *    job over the tabs and morphs across the new-job and check-in stages itself (same
 *    RunnerStateStore). Fronted for whichever KMP stage is current — so a cold start / restart
 *    *directly at check-in* surfaces it too, not just a fresh new job.
 *  - **Backgrounded** (app alive, not foreground) **and `RUNNER_NEW_JOB`**: a draw-over-other-apps
 *    new-job overlay ([NewJobOverlaySpec] presented on the shared [ComposeOverlayHost]) — so a runner
 *    in another app still sees the new job. This is the path that surfaces the overlay off Dart polling
 *    while the process is alive; it needs no push. Gated only on the `SYSTEM_ALERT_WINDOW` permission
 *    ([Settings.canDrawOverlays] — graceful: skip → FCM notification covers it); AWOL-vs-job precedence
 *    is the host's per-spec priority, so no cross-feature "already showing" guard is needed here.
 *    The **terminated** case (process dead → no polling, no plugin) is handled instead by
 *    [com.snabbit.runner.push.SnabbitPushService] off a data-only new-job FCM. The check-in stage
 *    has no draw-over — it waits for the next resume to front the host.
 *
 * [ActivityAware] because fronting/gating needs the host Activity + its lifecycle. Two triggers
 * cover both arrival cases: the `store.state` collector (stage arrives now) and an `ON_RESUME`
 * re-check (arrived while backgrounded, then resumed — which also tears the draw-over down and
 * fronts the host). A single-launch guard ([launchedForCurrentJob]) stops a re-front on every
 * state push — including the new-job → check-in advance, since the host stays up and its overlay
 * morphs; it resets once the state leaves the KMP-hosted set.
 */
class JobScreenLauncherPlugin : FlutterPlugin, ActivityAware, KoinComponent {

    private val store: RunnerStateStore by inject()

    /** RC gateway (mirror-backed, sync) — gates the draw-over-other-apps overlay (ECPO-860 #8). */
    private val remoteConfig: RemoteConfigGateway by inject()

    /**
     * Native nav back stack (process-scoped Koin singleton). Non-empty only once the KMP home
     * shell has been established — i.e. the `mqtt_config` cohort was routed through the KMP stack
     * at login (`RegistrationNavigation.openKMPStackForMqttCohort` → `bottom_nav_shell`). A
     * backward-compat / non-cohort runner stays on the Flutter `PartnerHome` and never seeds it, so
     * an empty stack means "this runner is Flutter-hosted" — the gate [maybeLaunch] checks before
     * fronting the KMP host (ECPO-860).
     */
    private val navController: NavigationController by inject()

    private var activity: Activity? = null
    private var scope: CoroutineScope? = null
    private var configChannel: MethodChannel? = null

    private var launchedForCurrentJob = false
    private var overlayRunning = false

    /**
     * True while the last observed state was `RUNNER_NEW_JOB`, so the store collector can detect the
     * `NEW_JOB → (any other stage)` transition and silence the Dart-owned new-job alert loop then.
     */
    private var lastWidgetWasNewJob = false

    /**
     * Logged-in runner's profile `service_id`, pushed from Dart over [CONFIG_CHANNEL]. Held in Koin
     * ([JobServiceIdHolder]) so both surfaces read one source: the foreground `ActiveJobOverlay`
     * (New-Job header Cook vs Expert glyph) and the backgrounded new-job overlay ([NewJobOverlaySpec],
     * tagged onto its start intent via [JobScreenExtras.EXTRA_SERVICE_ID]). Null until Dart pushes it (header then
     * falls back to the envelope-derived category).
     */
    private val serviceIdHolder: JobServiceIdHolder by inject()

    /**
     * Localized job-surface labels, pushed from Dart's `LanguageProvider` settle (keys =
     * [JobScreenExtras] extra names). Tagged as string extras onto BOTH launch intents so
     * [JobActivity] and the overlay build the same localized [JobScreenExtras.stringsFrom] /
     * [JobScreenExtras.delayedCheckinStringsFrom]. Empty until Dart pushes — extras then fall
     * back to the English defaults.
     */
    @Volatile
    private var jobLabels: Map<String, String> = emptyMap()

    /**
     * Live session mirror for the runner id (`UserProfileProvider` settle) and the
     * `expert_ameyo_support` Remote Config flag (delayed check-in FR-13). Written straight into the
     * core [RunnerSessionStore] — NOT frozen into Intent extras — so a push that lands after
     * `JobActivity` launched (cold start mid-job, mid-session RC flip) still reaches the running
     * engagement; KMP consumers read the store live at use time, matching Dart's tap-time reads.
     */
    private val session: RunnerSessionStore by inject()

    private val resumeObserver = LifecycleEventObserver { _, event ->
        if (event == Lifecycle.Event.ON_RESUME) {
            // Back in foreground — drop any draw-over and let the fronted host + its overlay take over.
            if (overlayRunning) {
                stopOverlay()
                launchedForCurrentJob = false
            }
            maybeLaunch()
        }
    }

    /**
     * Re-arm the new-job alert when the app returns to the foreground with an offer STILL pending.
     * The store collector's rising-edge START fires only once per NEW_JOB arrival; a runner who
     * backgrounded during a live offer and dismissed the notification (which stops the loop) gets no
     * new edge on resume, so the sound wouldn't return. Mirrors the poll cohort's resume
     * `current_state` re-arm (the mqtt cohort has no such poll). Driven off [AppForegroundTracker]'s
     * process-wide foreground edge — NOT the host Activity's `ON_RESUME` — so it also fires when the
     * KMP `NavigationHostActivity` is the foreground surface and MainActivity stays STOPPED behind it.
     * On a cold open the store isn't seeded yet at the first foreground edge, so this no-ops and the
     * collector's edge handles the initial play — no double-arm.
     */
    private val enterForeground: () -> Unit = {
        if (store.snapshot()?.widgetName == NEW_JOB) {
            configChannel?.invokeMethod("newJobAlertStart", null)
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        configChannel = MethodChannel(binding.binaryMessenger, CONFIG_CHANNEL).apply {
            setMethodCallHandler(::handleConfig)
        }
        AppForegroundTracker.onEnterForeground = enterForeground
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        configChannel?.setMethodCallHandler(null)
        configChannel = null
        // Only clear if a newer engine hasn't already replaced it (engine-restart race).
        if (AppForegroundTracker.onEnterForeground === enterForeground) {
            AppForegroundTracker.onEnterForeground = null
        }
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) = start(binding.activity)

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        start(binding.activity)

    override fun onDetachedFromActivityForConfigChanges() = stop()

    override fun onDetachedFromActivity() = stop()

    private fun handleConfig(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setServiceId" -> {
                serviceIdHolder.set(call.argument<Int>("service_id"))
                result.success(null)
            }
            "setRunnerId" -> {
                session.setRunnerId(call.argument<Int>("runner_id"))
                result.success(null)
            }
            "setAmeyoSupport" -> {
                session.setAmeyoSupport(call.argument<Boolean>("enabled") ?: false)
                result.success(null)
            }
            "setJobStrings" -> {
                jobLabels = call.argument<Map<String, String>>("labels").orEmpty()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun start(host: Activity) {
        stop() // idempotent on re-attach
        activity = host
        (host as? LifecycleOwner)?.lifecycle?.addObserver(resumeObserver)
        val launcherScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
        scope = launcherScope
        launcherScope.launch {
            store.state.collect { state ->
                val widget = state?.widgetName
                android.util.Log.i(TAG, "store.state widget=$widget")
                // Drive the Dart-owned new-job alert off the rising/falling edge of RUNNER_NEW_JOB —
                // START when the state ENTERS it, STOP when it LEAVES (accepted / denied / expired).
                // `store.state` is a MutableStateFlow that replays its current value to a fresh
                // subscriber, so a cold-open into a still-pending offer fires the START here on the
                // first emission (lastWidgetWasNewJob starts false) — the fail-proof, transport-agnostic
                // trigger the mqtt cohort's dropped FCM push missed. Both edges go over THIS plugin's own
                // `configChannel`, NOT ProfileActionsPlugin: that channel is created in onAttachedToEngine,
                // which Flutter guarantees runs before onAttachedToActivity (where this observer starts) —
                // so the channel is always live when an edge fires, even on a warm reopen where the cached
                // state makes the first emission immediate. Routing through a *separate* plugin raced its
                // attach and dropped the START (`channel=false`). Edge-guarded so a NEW_JOB -> NEW_JOB
                // re-offer neither restarts nor stops the already-playing loop (it carries the fresh offer).
                if (!lastWidgetWasNewJob && widget == NEW_JOB) {
                    configChannel?.invokeMethod("newJobAlertStart", null)
                }
                if (lastWidgetWasNewJob && widget != NEW_JOB) {
                    configChannel?.invokeMethod("newJobAlertStop", null)
                }
                lastWidgetWasNewJob = widget == NEW_JOB
                // Reset the guards only when the job leaves the KMP-hosted set entirely
                // (a non-job / NotInJobFlow state) — NOT on any advance within the arc
                // (new-job → check-in → in-progress → post-checkout), so the already-open
                // host morphs across the stages instead of being re-launched. The overlay
                // self-dismisses on the same transitions (its ViewModel reads this store).
                if (!isKmpStage(widget)) {
                    launchedForCurrentJob = false
                    overlayRunning = false
                }
                maybeLaunch()
            }
        }
    }

    private fun stop() {
        scope?.cancel()
        scope = null
        (activity as? LifecycleOwner)?.lifecycle?.removeObserver(resumeObserver)
        activity = null
    }

    /**
     * Routes the current KMP-hosted job stage: foreground → front [NavigationHostActivity] (its
     * `ActiveJobOverlay` morphs across the stages itself); backgrounded + `RUNNER_NEW_JOB` → the
     * new-job overlay on [ComposeOverlayHost] when permitted. No-ops if we've already launched for this engagement.
     * When backgrounded and no overlay is shown (not a new job, or overlay unavailable), the guard
     * is intentionally left unset so [resumeObserver] fronts the host on the next resume — covering
     * a **cold start / restart directly into check-in, in-progress or post-checkout**.
     */
    private fun maybeLaunch() {
        val host = activity ?: return
        if (launchedForCurrentJob) return
        val widget = store.snapshot()?.widgetName
        if (!isKmpStage(widget)) return

        // KMP hosts the job arc only when the KMP home shell is the app's surface — i.e. the native
        // back stack has been seeded (the `mqtt_config` cohort routed through
        // `RegistrationNavigation.openKMPStackForMqttCohort` → `bottom_nav_shell`). A backward-compat
        // / non-cohort runner stays on the Flutter `PartnerHome` and never seeds it, yet Dart still
        // mirrors `current_state` here (the KMP publish is not cohort-gated), so a new job would front
        // `NavigationHostActivity` onto an EMPTY back stack — which `SnabbitNavHost` immediately exits
        // (`onExit` → `finish`), the brief white "KMP screen + loader" flash before bouncing back to
        // Flutter (ECPO-860). Bail so the Dart surface owns the job.
        if (navController.backStack.isEmpty()) {
            android.util.Log.i(TAG, "maybeLaunch skipped: no KMP stack (Flutter-hosted runner) widget=$widget")
            return
        }

        android.util.Log.i(
            TAG,
            "maybeLaunch widget=$widget fg=${AppForegroundTracker.isForeground} " +
                "canDraw=${Settings.canDrawOverlays(host)} " +
                "newJobUp=${ComposeOverlayHost.isShowing(NewJobOverlaySpec.KEY)}",
        )

        // Foreground = ANY of our Activities is visible (process-wide [AppForegroundTracker]),
        // NOT this plugin's host lifecycle. The plugin attaches to the Flutter [MainActivity],
        // but for a KMP-cohort runner the foreground surface is [NavigationHostActivity] and
        // MainActivity sits STOPPED behind it — so a host-RESUMED check would misread the live app
        // as backgrounded and wrongly draw the new-job overlay OVER the foreground app instead of
        // fronting the host. (Reached only with a non-empty KMP stack, per the gate above.)
        if (AppForegroundTracker.isForeground) {
            launchedForCurrentJob = true
            host.startActivity(
                Intent(host, NavigationHostActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                    .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    // REORDER_TO_FRONT is a no-op recreate if the OS already reclaimed the
                    // host — onCreate re-runs, and this always targets the bottom-nav shell,
                    // so it needs EXTRA_ROOT_SHELL too or the bars fall back to opaque black.
                    .putExtra(NavigationHostActivity.EXTRA_ROOT_SHELL, true),
            )
            return
        }

        // Backgrounded (app alive): the draw-over-other-apps overlay is a NEW_JOB-only attention grab
        // (the check-in stage just waits for the next resume to front the host). Polling-driven — no
        // push needed. Presented on the generic [ComposeOverlayHost] via [NewJobOverlaySpec] (the former
        // standalone NewJobOverlayService, refactored onto the shared host). Gated on the
        // SYSTEM_ALERT_WINDOW permission AND the `expert_show_new_job_overlay_on_other_apps` RC flag (default
        // false, ECPO-860 #8); AWOL-vs-job precedence is the host's per-spec priority (penalty beats
        // opportunity), so no cross-feature "already showing" guard is needed here.
        if (widget == NEW_JOB &&
            Settings.canDrawOverlays(host) &&
            remoteConfig.getBool(NewJobOverlaySpec.RC_SHOW_ON_OTHER_APPS, false)
        ) {
            launchedForCurrentJob = true
            overlayRunning = true
            try {
                android.util.Log.i(TAG, "Starting new-job overlay (ComposeOverlayHost, backgrounded, polling-driven)")
                ComposeOverlayHost.start(host, NewJobOverlaySpec.KEY) {
                    serviceIdHolder.serviceId.value?.let {
                        putExtra(JobScreenExtras.EXTRA_SERVICE_ID, it)
                    }
                }
            } catch (e: Exception) {
                // Android 15+ (API 35) can reject a background FGS start here
                // (ForegroundServiceStartNotAllowedException): the SYSTEM_ALERT_WINDOW
                // exemption needs an already-visible overlay window, which doesn't exist yet.
                // The FCM new-job notification covers the gap; leave the guards set so the next
                // resume tears the (never-started) overlay down as a no-op and fronts the host.
                android.util.Log.e(TAG, "New-job overlay FGS start blocked; FCM fallback", e)
            }
        }
    }

    /**
     * The lifecycle stages the KMP job UI hosts — the full new-job → check-in → in-progress →
     * post-checkout arc; everything else is Dart-rendered. In-progress + post-checkout are included
     * so a **cold start directly into those stages** (app killed mid-job, then reopened) still
     * fronts the KMP host rather than stranding the runner on the Dart in-progress / completed screen.
     */
    private fun isKmpStage(widget: String?): Boolean =
        widget == NEW_JOB || widget == POST_ACCEPT || widget == CHECK_IN ||
            widget == IN_PROGRESS || widget == POST_CHECKOUT

    private fun stopOverlay() {
        // Tears the window down only if the new-job spec owns it — never an
        // AWOL window that outranked us.
        activity?.let { ComposeOverlayHost.dismissIfShowing(it, NewJobOverlaySpec.KEY) }
        overlayRunning = false
    }

    private companion object {
        const val TAG = "JobScreenLauncher"
        // Mirror JobWidgetName (internal to :shared, so not importable here).
        const val NEW_JOB = "RUNNER_NEW_JOB"
        const val POST_ACCEPT = "RUNNER_JOB_POST_ACCEPT"
        const val CHECK_IN = "RUNNER_JOB_CHECK_IN"
        const val IN_PROGRESS = "RUNNER_JOB_IN_PROGRESS"
        const val POST_CHECKOUT = "RUNNER_POST_CHECKOUT"
        const val CONFIG_CHANNEL = "com.snabbit.runner/job_overlay"
    }
}
