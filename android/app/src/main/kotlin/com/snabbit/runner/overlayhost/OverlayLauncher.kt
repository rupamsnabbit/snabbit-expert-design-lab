package com.snabbit.runner.overlayhost

import android.app.Activity
import android.app.Application
import android.app.KeyguardManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.util.Log
import androidx.core.app.NotificationCompat
import com.snabbit.runner.R
import com.snabbit.runner.shared.core.runnerstate.RunnerStateStore
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import org.koin.core.context.GlobalContext

/**
 * The generic, store-driven overlay launcher — `JobScreenLauncherPlugin`'s
 * `maybeLaunch` generalized over [OverlaySpec]s and **Application-context
 * scoped, deliberately NOT ActivityAware** (TRD §8 killed-state requirement):
 * AWOL suppresses notification banners (FR-12), so the overlay is the only
 * killed-state visual — the high-priority FCM data message revives the
 * process, `Application.onCreate` re-arms this launcher, the push handler's
 * `current_state` re-fetch lands in [RunnerStateStore], and the emission
 * fires the launch. No Activity needs to exist at any point.
 *
 * Three-way routing per emission, for the highest-priority triggered spec
 * (launch gates: RC flag pushed from Dart + `canDrawOverlays`):
 *  - **foreground** → nothing to launch — the in-app surface renders it (FR-09);
 *  - **background + PiP** → bring the app to the foreground instead of
 *    stacking a window over the app's own PiP window (§9 PiP rule);
 *  - **background + unlocked** → [ComposeOverlayHost] window;
 *  - **background + keyguard locked** → full-screen-intent notification
 *    launching [LockScreenAlertActivity] (`TYPE_APPLICATION_OVERLAY` never
 *    draws over the keyguard). Android 14+: checked via
 *    `canUseFullScreenIntent()`, degrading to alarm-now-card-at-unlock.
 *
 * Visibility is tracked with [Application.ActivityLifecycleCallbacks];
 * [LockScreenAlertActivity] is excluded — it *is* an alert surface, not the
 * app coming foreground. Interested features observe via [addVisibilityListener]
 * (the AWOL host binder forwards it to the coordinator's routing).
 */
class OverlayLauncher(private val app: Application) {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val enabledKeys = mutableSetOf<String>()
    private val visibilityListeners = mutableListOf<(Boolean, Boolean) -> Unit>()

    private var resumedActivities = 0
    // Most-recent STARTED (visible) activity — the basis for PiP detection. A
    // PiP window is STARTED but PAUSED, so this is deliberately NOT cleared on
    // pause (unlike the resumed count); clearing it there would make isInPip
    // unobservable and the §9 PiP routing rule dead.
    private var startedActivity: Activity? = null
    private var broughtForwardForPip = false

    private val isForeground: Boolean get() = resumedActivities > 0
    private val isInPip: Boolean
        get() = startedActivity?.isInPictureInPictureMode == true

    // The visibility signal reported to the AWOL coordinator (§9 routing). A
    // locked device is never "foreground" even if an activity is still resumed
    // underneath the keyguard — otherwise the VM would route the in-app HOME_CARD
    // and the lock-screen alert's `visible` flow would immediately finish it (B8).
    private val isEffectivelyForeground: Boolean
        get() = resumedActivities > 0 && !isKeyguardLocked()

    private fun isKeyguardLocked(): Boolean = try {
        (app.getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager)?.isKeyguardLocked == true
    } catch (e: Exception) {
        Log.e(TAG, "Keyguard query failed; treating device as unlocked", e)
        false
    }

    fun start() {
        app.registerActivityLifecycleCallbacks(lifecycleCallbacks)
        val koin = GlobalContext.getOrNull() ?: return
        // Re-hydrate the per-spec gates persisted by [setEnabled]: an FCM-revived
        // process (TRD §8 killed-state path) never gets the Dart config push —
        // MainActivity, where the config plugin attaches, never runs — so the
        // last-known flag must survive process death or the launcher ships dark
        // exactly when it is the only alert surface.
        val specKeys = try {
            koin.getAll<OverlaySpec>().map { it.key }
        } catch (e: Exception) {
            Log.e(TAG, "OverlaySpec enumeration failed during gate hydration", e)
            emptyList()
        }
        synchronized(enabledKeys) {
            specKeys.filterTo(enabledKeys) { persistedEnabled(app, it) }
        }
        val store = koin.get<RunnerStateStore>()
        scope.launch {
            store.state.collect { maybeLaunch() }
        }
    }

    /** Feature RC kill-switch, pushed from Dart (per spec key). Default OFF — ships dark (TR-07). */
    fun setEnabled(key: String, enabled: Boolean) {
        synchronized(enabledKeys) { if (enabled) enabledKeys.add(key) else enabledKeys.remove(key) }
        prefs(app).edit().putBoolean(PREF_ENABLED_PREFIX + key, enabled).apply()
        // Breadcrumb: confirms the RC kill-switch actually reached the native gate
        // (Dart → OverlayLauncherPlugin → here). If an overlay never appears while
        // this logs enabled=false, the flag — not the launcher — is the blocker.
        Log.i(TAG, "setEnabled: key=$key enabled=$enabled")
        maybeLaunch()
    }

    /** Observe (foreground, inPip) — fired on every activity resume/pause transition. */
    fun addVisibilityListener(listener: (foreground: Boolean, inPip: Boolean) -> Unit) {
        visibilityListeners.add(listener)
        listener(isEffectivelyForeground, isInPip)
    }

    private fun maybeLaunch() {
        val koin = GlobalContext.getOrNull() ?: return
        val state = koin.get<RunnerStateStore>().snapshot()
        val allSpecs = try {
            koin.getAll<OverlaySpec>()
        } catch (e: Exception) {
            Log.e(TAG, "OverlaySpec resolution failed", e)
            emptyList()
        }
        val enabled = synchronized(enabledKeys) { enabledKeys.toSet() }
        // suppressedFor: a spec whose feature already dismissed this state's alert
        // (e.g. AWOL "I Understand") is filtered out here — otherwise every store
        // emission would restart the host FGS (and its dim window) only for the
        // spec's `visible` to replay false and tear it straight down. A NEW phase
        // is not in the feature's dismissed memory, so it still presents.
        val triggered = allSpecs.filter { it.shouldTrigger(state) && !it.suppressedFor(state) }
        val spec = triggered.filter { it.key in enabled }.maxByOrNull { it.priority } ?: run {
            // Diagnostic breadcrumb (was silent): a spec WANTS to show but its RC
            // kill-switch never reached [enabledKeys] — the single most common
            // "overlay never appears" cause after a missing permission. Surface
            // it so the flag/permission split is diagnosable from logcat.
            triggered.firstOrNull()?.let {
                Log.w(TAG, "maybeLaunch: ${it.key} triggered but not enabled (RC flag off / not yet pushed); enabledKeys=$enabled")
            }
            broughtForwardForPip = false
            return
        }

        val keyguard = app.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        val locked = keyguard.isKeyguardLocked

        // In-app surface owns the alert only when the app is genuinely in use —
        // foreground AND unlocked. A locked device is never "in use" even if an
        // activity is still resumed underneath the keyguard, so a stale resumed
        // count must not suppress the lock-screen alert (B8).
        //
        // Exception: a spec that [drawsOverForegroundApp] (AWOL — a safety alert) must
        // NOT be suppressed in the foreground; it draws over the open app and the VM
        // routes OVERLAY in foreground so the window content renders.
        if (isForeground && !locked && !spec.drawsOverForegroundApp) {
            Log.d(TAG, "maybeLaunch: app foreground+unlocked → in-app surface owns ${spec.key} (FR-09)")
            return
        }

        // PiP (unlocked): the app's own window is on screen (STARTED, not RESUMED)
        // — bring it forward instead of stacking an overlay on it. Once per episode.
        if (isInPip && !locked) {
            if (!broughtForwardForPip) {
                broughtForwardForPip = true
                bringAppToForeground()
            }
            return
        }

        // Locked device (B8): a TYPE_APPLICATION_OVERLAY window can NOT draw over
        // the keyguard, so this path posts a full-screen-intent notification
        // instead — which needs USE_FULL_SCREEN_INTENT / POST_NOTIFICATIONS, NOT
        // SYSTEM_ALERT_WINDOW. It MUST be reached BEFORE the canDrawOverlays gate
        // below: that gate previously suppressed the lock-screen alert entirely on
        // a device without overlay permission (the original B8 cause).
        if (locked) {
            // A TYPE_APPLICATION_OVERLAY window cannot draw over the keyguard: a
            // window that went up before the device locked would survive occluded
            // underneath it and double-present alongside the keyguard card after
            // unlock — tear it down before posting the alert.
            if (ComposeOverlayHost.isShowing(spec.key)) {
                Log.d(TAG, "maybeLaunch: device locked with ${spec.key} overlay window up — tearing it down before the lock-screen alert")
                ComposeOverlayHost.dismissIfShowing(app, spec.key)
            }
            // One alert at a time: a payload refresh (e.g. the red-card count
            // bump) must not re-fire the full-screen intent into the activity
            // that is already showing the live card.
            if (!LockScreenAlertActivity.isShowing) {
                postLockScreenAlert(spec)
            } else {
                Log.d(TAG, "maybeLaunch: lock-screen alert already showing for ${spec.key}")
            }
            return
        }

        // Unlocked background: the draw-over-other-apps window (B7). Needs
        // SYSTEM_ALERT_WINDOW; when missing we degrade (the alarm already fired
        // Dart-side; the home card shows at next open, TR-06) — but log it, since
        // a revoked/never-granted overlay permission is the prime reason the
        // over-other-apps alert never appears. Grant is requested at onboarding
        // (Dart: select_language_v2 → OverlayPermissionDialog, gated on
        // expert_enable_awol_v2_overlay), so no jarring mid-breach prompt here.
        if (!Settings.canDrawOverlays(app)) {
            Log.w(TAG, "maybeLaunch: SYSTEM_ALERT_WINDOW not granted — cannot draw ${spec.key} over other apps; degrading (alarm fired Dart-side, card at next open, TR-06)")
            return
        }
        if (ComposeOverlayHost.isShowing(spec.key)) {
            Log.d(TAG, "maybeLaunch: ${spec.key} overlay window already showing")
            return
        }
        ComposeOverlayHost.start(app, spec.key)
    }

    /**
     * The locked-device branch: a full-screen-intent notification launching the
     * generic [LockScreenAlertActivity] (the alarm-clock pattern — screen lights
     * up, card visible on the keyguard).
     */
    private fun postLockScreenAlert(spec: OverlaySpec) {
        val nm = app.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE &&
            !nm.canUseFullScreenIntent()
        ) {
            // User/Play revoked the special access — degrade gracefully to
            // today's behaviour: alarm now (Dart), card at unlock.
            // TODO(AWOL): there is no onboarding request point for
            // USE_FULL_SCREEN_INTENT (unlike SYSTEM_ALERT_WINDOW, which is
            // requested in Dart select_language_v2 → OverlayPermissionDialog).
            // Android 14+ can auto-revoke it for non-calling/alarm apps; if this
            // branch is hit in the field, add a Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT
            // request alongside the overlay-permission onboarding. Logged, not
            // forced, so no jarring mid-breach system-settings prompt.
            Log.w(TAG, "postLockScreenAlert: USE_FULL_SCREEN_INTENT not granted — lock-screen alert suppressed for ${spec.key}; degrading (alarm fired Dart-side, card at unlock)")
            return
        }
        try {
            nm.createNotificationChannel(
                NotificationChannel(
                    LOCK_CHANNEL_ID,
                    "Snabbit Urgent Alerts",
                    NotificationManager.IMPORTANCE_HIGH,
                ).apply {
                    // Silence the CHANNEL (no sound/vibration) rather than the
                    // notification: a SILENT notification (setSilent(true)) is
                    // non-alerting and Android 14+ will NOT fire its full-screen
                    // intent (screen stays off on a locked device). A silent but
                    // still high-importance channel keeps the FSI eligible while
                    // leaving the alarm to the Dart push handler (FR-12).
                    setSound(null, null)
                    enableVibration(false)
                    setShowBadge(false)
                },
            )
            val fullScreen = PendingIntent.getActivity(
                app,
                spec.key.hashCode(),
                Intent(app, LockScreenAlertActivity::class.java)
                    .putExtra(ComposeOverlayHost.EXTRA_SPEC_KEY, spec.key)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            val notification = NotificationCompat.Builder(app, LOCK_CHANNEL_ID)
                .setContentTitle("Snabbit")
                .setSmallIcon(R.mipmap.ic_launcher)
                .setCategory(NotificationCompat.CATEGORY_ALARM)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                // NOTE: do NOT setSilent(true) — a silent notification is
                // non-alerting and Android 14+ suppresses its full-screen intent
                // (screen never wakes on lock). The channel above is silenced
                // instead, so this stays sound-free while the FSI still fires.
                .setAutoCancel(true)
                .setFullScreenIntent(fullScreen, true)
                .build()
            nm.notify(LOCK_NOTIFICATION_ID, notification)
        } catch (e: Exception) {
            // POST_NOTIFICATIONS denied or notify failure — degrade (TR-06).
            Log.e(TAG, "Failed to post lock-screen alert for ${spec.key}", e)
        }
    }

    private fun bringAppToForeground() {
        try {
            val launch = app.packageManager.getLaunchIntentForPackage(app.packageName)?.apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
            }
            if (launch != null) app.startActivity(launch)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to bring app to foreground", e)
        }
    }

    private val lifecycleCallbacks = object : Application.ActivityLifecycleCallbacks {
        override fun onActivityResumed(activity: Activity) {
            // Alert surfaces don't count as "the app is in use" — otherwise the
            // keyguard card's own resume would flip routing to the in-app surface.
            if (activity is LockScreenAlertActivity) return
            resumedActivities++
            startedActivity = activity
            notifyVisibility()
        }

        override fun onActivityPaused(activity: Activity) {
            if (activity is LockScreenAlertActivity) return
            resumedActivities = (resumedActivities - 1).coerceAtLeast(0)
            // startedActivity is intentionally NOT cleared here: a PiP window is
            // paused but still started/visible, and isInPip reads it.
            notifyVisibility()
        }

        override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) = Unit
        override fun onActivityStarted(activity: Activity) {
            if (activity is LockScreenAlertActivity) return
            startedActivity = activity
        }
        override fun onActivityStopped(activity: Activity) {
            if (activity is LockScreenAlertActivity) return
            if (startedActivity === activity) startedActivity = null
        }
        override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) = Unit
        override fun onActivityDestroyed(activity: Activity) {
            if (startedActivity === activity) startedActivity = null
        }
    }

    private fun notifyVisibility() {
        val foreground = isEffectivelyForeground
        val pip = isInPip
        visibilityListeners.forEach { it(foreground, pip) }
        maybeLaunch()
    }

    companion object {
        private const val TAG = "OverlayLauncher"
        // v2: the original channel was created with a default sound; channels
        // are immutable after creation, so a new id is needed to apply the
        // silent (sound/vibration-off) config that lets the FSI fire.
        private const val LOCK_CHANNEL_ID = "overlay_lockscreen_channel_v2"
        internal const val LOCK_NOTIFICATION_ID = 9103
        private const val PREFS_FILE = "overlay_launcher"
        private const val PREF_ENABLED_PREFIX = "enabled_"

        private fun prefs(context: Context) =
            context.getSharedPreferences(PREFS_FILE, Context.MODE_PRIVATE)

        /**
         * Last per-spec flag value pushed from Dart, surviving process death.
         * Read by [com.snabbit.runner.SnabbitRunnerApplication] to seed the AWOL
         * coordinator's routing flags in lockstep with the launcher's own gate,
         * so launch decision and surface routing can't disagree on a killed-state
         * revival either.
         */
        fun persistedEnabled(context: Context, key: String): Boolean =
            prefs(context).getBoolean(PREF_ENABLED_PREFIX + key, false)

        /** Process singleton, armed by [com.snabbit.runner.SnabbitRunnerApplication]. */
        @Volatile
        var instance: OverlayLauncher? = null
            private set

        fun init(app: Application): OverlayLauncher =
            instance ?: OverlayLauncher(app).also {
                instance = it
                it.start()
            }
    }
}
