package com.snabbit.runner.overlayhost

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.IBinder
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import androidx.compose.material3.MaterialTheme
import androidx.compose.ui.platform.ComposeView
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.setViewTreeLifecycleOwner
import androidx.savedstate.setViewTreeSavedStateRegistryOwner
import com.snabbit.runner.R
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import org.koin.mp.KoinPlatform.getKoin

/**
 * The ONE blank draw-over-other-apps foreground service (TRD §8): owns only
 * the feature-agnostic window plumbing extracted from `NewJobOverlayService`
 * — the [OverlayLifecycleOwner] dance, the silent FGS notification, the
 * single-overlay guard, the `addView` SecurityException (TOCTOU) catch,
 * `removeViewImmediate` on dismiss, and bring-to-foreground. Feature UIs plug
 * in as Koin-registered [OverlaySpec]s resolved by the [EXTRA_SPEC_KEY]
 * intent key.
 *
 * A single host makes "at most one overlay window app-wide" **structural**:
 * a start while a window is up is ignored unless the new spec's [OverlaySpec.priority]
 * is higher (penalty beats opportunity — AWOL > new-job), in which case the
 * current window is replaced. This host-internal comparison supersedes the
 * legacy cross-feature `OverlayService.instance` check.
 *
 * Dismissal is feed-driven: the host collects [OverlaySpec.visible] and tears
 * the window down (then stops) the moment it emits false.
 */
class ComposeOverlayHost : Service(), OverlayHostSession {

    private lateinit var lifecycleOwner: OverlayLifecycleOwner
    private lateinit var windowManager: WindowManager

    // Window-lifetime UI scope: drives the spec's content + visible collector;
    // cancelled in onDestroy so nothing outlives the window.
    override val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    override var startIntent: Intent? = null
        private set

    private var overlayView: View? = null
    private var currentSpec: OverlaySpec? = null

    /** The current spec's `visible` collector — cancelled on dismiss/replace so a
     *  replaced spec's later `false` can never tear down its successor's window. */
    private var visibleJob: Job? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        lifecycleOwner = OverlayLifecycleOwner().apply { onCreate() }
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager

        createNotificationChannel()
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Snabbit")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setSilent(true)
            .build()
        startForeground(NOTIFICATION_ID, notification)

        lifecycleOwner.onStart()
        lifecycleOwner.onResume()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val key = intent?.getStringExtra(EXTRA_SPEC_KEY)
        val spec = resolveSpec(key)
        if (spec == null) {
            Log.e(TAG, "No OverlaySpec registered for key=$key")
            if (overlayView == null) stopSelf()
            return START_NOT_STICKY
        }
        val current = currentSpec
        when {
            // Single overlay: ignore re-delivery / duplicate / lower-priority starts.
            current == null -> show(spec, intent)
            spec.key == current.key -> Unit
            spec.priority > current.priority -> {
                dismissOverlay()
                show(spec, intent)
            }
            else -> Log.d(TAG, "Ignoring ${spec.key} while higher-priority ${current.key} is up")
        }
        return START_NOT_STICKY
    }

    private fun resolveSpec(key: String?): OverlaySpec? {
        if (key == null) return null
        return try {
            getKoin().getAll<OverlaySpec>().firstOrNull { it.key == key }
        } catch (e: Exception) {
            Log.e(TAG, "OverlaySpec resolution failed for key=$key", e)
            null
        }
    }

    private fun show(spec: OverlaySpec, intent: Intent?) {
        currentSpec = spec
        startIntent = intent

        val composeView = ComposeView(this).apply {
            setViewTreeLifecycleOwner(lifecycleOwner)
            setViewTreeSavedStateRegistryOwner(lifecycleOwner)
            setContent {
                // MaterialTheme outside (the DS isn't on :app's classpath);
                // each spec applies SnabbitTheme inside its shared surface.
                MaterialTheme {
                    spec.Content(this@ComposeOverlayHost)
                }
            }
        }
        if (!addOverlayView(composeView, spec.window)) return // addView failed → already stopped

        // Feed-driven dismissal: visible=false → tear down + stop. Collected
        // only AFTER the window is up: spec.visible replays its current value
        // synchronously (Main.immediate), so starting it first would let a
        // false current value run dismissAndStop() while overlayView is still
        // null — nulling currentSpec while the view gets added anyway (a dim
        // flash + an untracked, leaked overlay window).
        visibleJob = spec.visible(this)
            .onEach { visible -> if (!visible) dismissAndStop() }
            .launchIn(scope)
    }

    /** Window params per [OverlayWindowStyle]; offsets/sizes in dp only (legacy mini-pill lesson).
     *  Returns true iff [windowManager.addView] succeeded (else it stopped the service). */
    private fun addOverlayView(view: View, style: OverlayWindowStyle): Boolean {
        val params = when (style) {
            OverlayWindowStyle.DimModal -> WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_DIM_BEHIND,
                PixelFormat.TRANSLUCENT,
            ).apply {
                gravity = Gravity.CENTER
                dimAmount = SCRIM_DIM_AMOUNT
            }
            OverlayWindowStyle.Banner -> WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
                PixelFormat.TRANSLUCENT,
            ).apply { gravity = Gravity.TOP }
            OverlayWindowStyle.Pill -> WindowManager.LayoutParams(
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
                PixelFormat.TRANSLUCENT,
            ).apply { gravity = Gravity.CENTER }
        }
        return try {
            windowManager.addView(view, params)
            overlayView = view
            true
        } catch (e: SecurityException) {
            // Overlay permission revoked between the launcher's canDrawOverlays
            // check and here (TOCTOU). Degrade (TR-06) — the alarm already fired.
            Log.e(TAG, "Overlay permission revoked before addView", e)
            stopSelf()
            false
        } catch (e: Exception) {
            Log.e(TAG, "Failed to add overlay view", e)
            stopSelf()
            false
        }
    }

    private fun dismissOverlay() {
        visibleJob?.cancel()
        visibleJob = null
        overlayView?.let { view ->
            try {
                windowManager.removeViewImmediate(view)
            } catch (e: IllegalArgumentException) {
                // View already detached (e.g. service killed) — expected.
                Log.d(TAG, "Overlay view already detached: ${e.message}")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to remove overlay view", e)
            }
        }
        overlayView = null
        currentSpec = null
    }

    override fun dismissAndStop() {
        dismissOverlay()
        stopSelf()
    }

    /**
     * Bring the app to the foreground (e.g. after an overlay accept, or the PiP
     * routing rule). Starting an activity from this background foreground service
     * is permitted because the overlay holds `SYSTEM_ALERT_WINDOW` (the
     * background-activity-launch exemption).
     */
    override fun bringAppToForeground() {
        try {
            val launch = packageManager.getLaunchIntentForPackage(packageName)?.apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
            }
            if (launch != null) startActivity(launch)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to bring app to foreground", e)
        }
    }

    override fun onDestroy() {
        scope.cancel()
        lifecycleOwner.onPause()
        lifecycleOwner.onStop()
        dismissOverlay()
        lifecycleOwner.onDestroy()
        if (instance === this) instance = null
        super.onDestroy()
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Snabbit Alerts Overlay",
            NotificationManager.IMPORTANCE_LOW,
        ).apply { setShowBadge(false) }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    companion object {
        private const val TAG = "ComposeOverlayHost"
        private const val CHANNEL_ID = "overlay_host_channel"
        private const val NOTIFICATION_ID = 9102
        /** 50% black scrim behind the modal card. */
        private const val SCRIM_DIM_AMOUNT = 0.5f

        /** Intent extra naming the [OverlaySpec] to present. */
        const val EXTRA_SPEC_KEY = "extra_overlay_spec_key"

        // Host-internal only — never a cross-feature seam like the legacy
        // OverlayService.instance (specs/launchers use the companion helpers).
        @Volatile
        private var instance: ComposeOverlayHost? = null

        /** Whether a window for [key] is currently up. */
        fun isShowing(key: String): Boolean = instance?.currentSpec?.key == key

        /** Start (or priority-replace) the overlay for [key]; [configure] adds feature extras. */
        fun start(context: Context, key: String, configure: (Intent.() -> Unit)? = null) {
            val intent = Intent(context, ComposeOverlayHost::class.java)
                .putExtra(EXTRA_SPEC_KEY, key)
                .apply { configure?.invoke(this) }
            ContextCompat.startForegroundService(context, intent)
        }

        /** Tear down the window if [key] owns it (e.g. app resumed → in-app surface takes over). */
        fun dismissIfShowing(context: Context, key: String) {
            val host = instance ?: return
            if (host.currentSpec?.key == key) {
                context.stopService(Intent(context, ComposeOverlayHost::class.java))
            }
        }
    }
}
