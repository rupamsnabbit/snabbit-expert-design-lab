package com.snabbit.runner.overlayhost

import android.app.NotificationManager
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.material3.MaterialTheme
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import org.koin.mp.KoinPlatform.getKoin

/**
 * Generic lock-screen alert surface (TRD §8, decided 2026-07-09): a
 * `TYPE_APPLICATION_OVERLAY` window never draws over the keyguard, so when
 * the device is locked the launcher posts a full-screen-intent notification
 * that launches this activity instead — `setShowWhenLocked(true)` +
 * `setTurnScreenOn(true)`, the alarm-clock pattern: the screen lights up and
 * the card is visible on the keyguard.
 *
 * Renders the same [OverlaySpec.Content] the window host uses — no second UI
 * copy. Like the host, feature-agnostic: any spec can present on the keyguard
 * (resolved by the same [ComposeOverlayHost.EXTRA_SPEC_KEY]); the spec's
 * `visible` flow finishing the activity is the same feed-driven dismissal.
 */
class LockScreenAlertActivity : ComponentActivity(), OverlayHostSession {

    override val scope: CoroutineScope get() = lifecycleScope
    override val startIntent: Intent? get() = intent

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON,
            )
        }

        val key = intent?.getStringExtra(ComposeOverlayHost.EXTRA_SPEC_KEY)
        val spec = resolveSpec(key)
        if (spec == null) {
            Log.e(TAG, "No OverlaySpec registered for key=$key")
            finish()
            return
        }

        // The carrier notification did its job (launching us) — clear it (only ours).
        getSystemService(NotificationManager::class.java)
            ?.cancel(OverlayLauncher.LOCK_NOTIFICATION_ID)

        spec.visible(this)
            .onEach { visible -> if (!visible) finish() }
            .launchIn(lifecycleScope)

        setContent {
            MaterialTheme {
                spec.Content(this)
            }
        }
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

    override fun dismissAndStop() = finish()

    override fun bringAppToForeground() {
        try {
            val launch = packageManager.getLaunchIntentForPackage(packageName)?.apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
            }
            if (launch != null) startActivity(launch)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to bring app to foreground", e)
        }
        finish()
    }

    override fun onStart() {
        super.onStart()
        isShowing = true
    }

    override fun onStop() {
        isShowing = false
        super.onStop()
    }

    companion object {
        private const val TAG = "LockScreenAlertActivity"

        /**
         * Whether a keyguard alert is currently on screen — the launcher skips
         * re-posting the full-screen-intent notification while one is up, so a
         * payload refresh (red-card bump every poll) can't re-fire the intent
         * into the showing activity.
         */
        @Volatile
        var isShowing: Boolean = false
            private set
    }
}
