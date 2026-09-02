package com.snabbit.runner

import android.app.Activity
import android.app.Application
import android.os.Bundle
import android.os.SystemClock
import com.snabbit.runner.job.overlay.NewJobOverlaySpec
import com.snabbit.runner.overlayhost.ComposeOverlayHost
import com.snabbit.runner.shared.core.background.SnabbitForegroundService
import com.snabbit.runner.shared.core.realtime.WakeReason
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicLong

/**
 * Process-wide foreground signal: `true` while at least one Activity is STARTED
 * (visible). Registered once in [SnabbitRunnerApplication.onCreate] via
 * `registerActivityLifecycleCallbacks`.
 *
 * Read from any thread — the count is an [AtomicInteger], so no main-thread hop
 * is needed. That matters because the sole consumer,
 * [com.snabbit.runner.push.SnabbitPushService.onMessageReceived], runs on the FCM
 * binder thread.
 *
 * Why a hand-rolled counter and not the two obvious alternatives:
 *  - `ActivityManager` process importance would report `IMPORTANCE_FOREGROUND`
 *    whenever *any* foreground service is running. This app runs location /
 *    background foreground-services, so that signal is `true` even when the runner
 *    is looking at another app — the exact case the new-job draw-over exists for.
 *  - `androidx.lifecycle:lifecycle-process` (`ProcessLifecycleOwner`) is not on the
 *    classpath; adding it would also pull an `androidx.startup` provider into the
 *    merged manifest, which the build's compile step does not validate.
 * A visible-Activity count is the precise "is the runner looking at our UI right
 * now" question, and stays dependency-free.
 */
object AppForegroundTracker : Application.ActivityLifecycleCallbacks {

    private val startedActivities = AtomicInteger(0)

    /** `true` once any Activity has been started and not yet stopped. */
    val isForeground: Boolean
        get() = startedActivities.get() > 0

    /**
     * Invoked on the background→foreground edge (the first Activity becoming visible), on the main
     * thread. Set by [com.snabbit.runner.kmp_bridge.JobScreenLauncherPlugin] to re-arm the new-job
     * alert when the runner returns to the app with an offer still pending. Process-wide on purpose:
     * it fires for ANY foreground surface — MainActivity or the KMP `NavigationHostActivity` — which
     * a per-Activity `ON_RESUME` observer on MainActivity can't do (MainActivity stays STOPPED behind
     * the KMP host). Single-slot; the newest engine overwrites it and identity-clears on detach.
     */
    @Volatile
    var onEnterForeground: (() -> Unit)? = null

    override fun onActivityStarted(activity: Activity) {
        if (startedActivities.incrementAndGet() == 1) {
            // App just became foreground (first visible Activity). Tear down any draw-over new-job
            // overlay window so it never stacks on the in-app surface — the overlay exists only for
            // the backgrounded / terminated case. dismissIfShowing only stops the host when the
            // NEW-JOB spec owns it (never an AWOL window), and no-ops if nothing is showing.
            ComposeOverlayHost.dismissIfShowing(
                activity.applicationContext,
                NewJobOverlaySpec.KEY,
            )
            wakeRealtimeEngine()
            onEnterForeground?.invoke()
        }
    }

    /**
     * Reconcile realtime state on the background→foreground edge. `WakeReason.APP_FOREGROUND` was
     * declared with the engine but never wired, so returning to the app — the recovery every
     * runner instinctively tries — synced nothing for the MQTT cohort: the Dart on-resume fetch is
     * deliberately gated off for them, and a snapshot missed while backgrounded stayed missed
     * until the broker happened to publish again (a held accept spinner being the worst case).
     * One reconcile per foreground edge closes that.
     *
     * Throttled: the cohort exists to STOP polling, and a runner toggling between apps through a
     * shift must not turn this into an uncapped `current_state` poll. No-op when the engine isn't
     * running (polling cohort, or service down — the Dart resume-gap reopen owns that recovery).
     * Main thread, like the service's own wake calls.
     */
    private fun wakeRealtimeEngine() {
        val engine = SnabbitForegroundService.activeEngine ?: return
        val now = SystemClock.elapsedRealtime()
        val last = lastRealtimeWakeMs.get()
        if (now - last < REALTIME_WAKE_THROTTLE_MS) return
        if (!lastRealtimeWakeMs.compareAndSet(last, now)) return
        engine.onWakeSignal(WakeReason.APP_FOREGROUND)
    }

    // Long.MIN_VALUE / 2, not 0: elapsedRealtime() is ms since BOOT, so a 0 seed makes
    // `now - last < throttle` true for the first 10s of uptime and swallows the very first
    // foreground wake on the boot-then-immediately-open-the-app path. Halved to keep the
    // subtraction far from overflow.
    private val lastRealtimeWakeMs = AtomicLong(Long.MIN_VALUE / 2)
    private const val REALTIME_WAKE_THROTTLE_MS = 10_000L

    override fun onActivityStopped(activity: Activity) {
        // Guard against ever going negative (a stray onStop with no matching onStart
        // would otherwise wedge isForeground at false until it climbed back positive).
        startedActivities.updateAndGet { if (it > 0) it - 1 else 0 }
    }

    override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) = Unit
    override fun onActivityResumed(activity: Activity) = Unit
    override fun onActivityPaused(activity: Activity) = Unit
    override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) = Unit
    override fun onActivityDestroyed(activity: Activity) = Unit
}
