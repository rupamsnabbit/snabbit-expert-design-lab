package com.snabbit.runner.compose_overlay.service

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.IBinder
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.ComposeView
import androidx.core.app.NotificationCompat
import androidx.lifecycle.setViewTreeLifecycleOwner
import androidx.savedstate.setViewTreeSavedStateRegistryOwner
import com.snabbit.runner.R
import com.snabbit.runner.compose_overlay.data.OverlayWindowManager
import com.snabbit.runner.compose_overlay.domain.OverlayAction
import com.snabbit.runner.compose_overlay.domain.OverlayConfig
import com.snabbit.runner.compose_overlay.presentation.OverlayViewModel
import com.snabbit.runner.compose_overlay.presentation.model.BreachDisplayModel
import com.snabbit.runner.compose_overlay.presentation.model.MiniBreachDisplayModel
import com.snabbit.runner.compose_overlay.presentation.model.ReEnteredDisplayModel
import com.snabbit.runner.compose_overlay.presentation.ui.OverlayBannerContent
import com.snabbit.runner.compose_overlay.presentation.ui.OverlayDialogContent
import com.snabbit.runner.compose_overlay.presentation.ui.OverlayMiniContent

/**
 * Foreground service that hosts the native Compose overlay UI for AWOL breach
 * and re-entered states. Runs independently of the Flutter engine so the
 * overlay remains visible even when the app is backgrounded or task-removed.
 *
 * Lifecycle:
 *   Flutter (OverlayProvider) → MethodChannel → OverlayChannelManager
 *       → starts this service via Intent → OverlayService.onCreate()
 *       → wires OverlayViewModel callbacks → shows ComposeView via WindowManager
 *
 * The service uses [OverlayViewModel] for state management and
 * [OverlayWindowManager] for adding/removing views from the system window.
 */
class OverlayService : Service() {

    companion object {
        var instance: OverlayService? = null
            private set
        var channelManager: com.snabbit.runner.compose_overlay.data.OverlayChannelManager? = null

        private const val CHANNEL_ID = "overlay_service_channel"
        private const val NOTIFICATION_ID = 9001
        /** Maximum movement (in px) during a drag gesture to still count as a tap. */
        private const val DRAG_TAP_THRESHOLD_PX = 20f
        /** Maximum recursion depth for [bundleToMap] to prevent stack overflow. */
        private const val BUNDLE_MAX_DEPTH = 10

        const val ACTION_SHOW = "SHOW"
        const val ACTION_DISMISS = "DISMISS"
        const val EXTRA_TYPE = "type"
        const val EXTRA_CONFIG = "config"
    }

    private lateinit var lifecycleOwner: OverlayLifecycleOwner
    private lateinit var overlayWindowManager: OverlayWindowManager
    val viewModel = OverlayViewModel()

    override fun onCreate() {
        super.onCreate()
        instance = this

        lifecycleOwner = OverlayLifecycleOwner()
        lifecycleOwner.onCreate()

        val wm = getSystemService(Context.WINDOW_SERVICE) as android.view.WindowManager
        overlayWindowManager = OverlayWindowManager(wm)

        viewModel.onShowView = { config, isDialog ->
            showComposeView(config, isDialog)
        }
        viewModel.onDismissView = {
            overlayWindowManager.dismiss()
        }
        viewModel.onLaunchMapsIntent = { lat, lng ->
            launchMapsNavigation(lat, lng)
        }
        viewModel.onStopService = {
            stopSelf()
        }
        viewModel.onShowMiniView = { config ->
            showMiniComposeView(config)
        }

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

        // Wire ViewModel callbacks to the channel manager (service is now ready)
        channelManager?.wireViewModelCallbacks()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_SHOW -> {
                val type = intent.getStringExtra(EXTRA_TYPE) ?: "dialog"
                val configBundle = intent.getBundleExtra(EXTRA_CONFIG)
                val configMap = bundleToMap(configBundle)
                val config = OverlayConfig.fromMap(configMap)

                when (type) {
                    "banner" -> {
                        viewModel.onAction(OverlayAction.ShowBanner(config.message ?: "", "info"))
                        // Banner also needs the view — show it manually
                        showComposeView(config, false)
                    }
                    "mini" -> {
                        viewModel.onAction(OverlayAction.ShowMiniOverlay(config))
                    }
                    else -> {
                        viewModel.onAction(OverlayAction.ShowDialog(config))
                    }
                }
            }
            ACTION_DISMISS -> {
                viewModel.onAction(OverlayAction.Dismiss("programmatic"))
                stopSelf()
            }
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        // Clear ViewModel callbacks to break the reference cycle between the
        // service and ViewModel. Without this, the service instance leaks
        // because the ViewModel lambdas capture `this`.
        viewModel.onShowView = null
        viewModel.onDismissView = null
        viewModel.onLaunchMapsIntent = null
        viewModel.onStopService = null
        viewModel.onShowMiniView = null
        viewModel.onSendToFlutter = null
        viewModel.onEmitEvent = null

        lifecycleOwner.onPause()
        lifecycleOwner.onStop()
        overlayWindowManager.dismiss()
        lifecycleOwner.onDestroy()
        instance = null
        super.onDestroy()
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // Do NOT dismiss overlay or stop service — overlay must survive app swipe.
        // CTAs are handled natively and will still work.
        android.util.Log.i("OverlayService", "Task removed — overlay remains active")
        super.onTaskRemoved(rootIntent)
    }

    private fun showComposeView(config: OverlayConfig, isDialog: Boolean) {
        val composeView = ComposeView(this).apply {
            setViewTreeLifecycleOwner(lifecycleOwner)
            setViewTreeSavedStateRegistryOwner(lifecycleOwner)
            setContent {
                if (isDialog) {
                    val model = BreachDisplayModel.from(config)
                    OverlayDialogContent(
                        model = model,
                        onAction = { actionId, data ->
                            viewModel.onAction(OverlayAction.CTAClicked(actionId, data))
                        },
                    )
                } else {
                    val model = ReEnteredDisplayModel.from(config)
                    OverlayBannerContent(
                        model = model,
                        onAction = { actionId, data ->
                            viewModel.onAction(OverlayAction.CTAClicked(actionId, data))
                        },
                    )
                }
            }
        }

        if (isDialog) {
            overlayWindowManager.showDialog(composeView)
        } else {
            overlayWindowManager.showBanner(composeView)
        }
    }

    private fun showMiniComposeView(config: OverlayConfig) {
        val composeView = ComposeView(this).apply {
            setViewTreeLifecycleOwner(lifecycleOwner)
            setViewTreeSavedStateRegistryOwner(lifecycleOwner)
            setContent {
                val model = MiniBreachDisplayModel.from(config)
                var totalDrag by remember { mutableFloatStateOf(0f) }

                Box(
                    modifier = Modifier
                        .pointerInput(Unit) {
                            detectDragGestures(
                                onDragStart = { totalDrag = 0f },
                                onDrag = { change, dragAmount ->
                                    change.consume()
                                    totalDrag += kotlin.math.abs(dragAmount.x) + kotlin.math.abs(dragAmount.y)
                                    overlayWindowManager.updatePosition(
                                        dragAmount.x.toInt(),
                                        dragAmount.y.toInt(),
                                    )
                                },
                                onDragEnd = {
                                    // If total movement was tiny, treat as a tap
                                    if (totalDrag < DRAG_TAP_THRESHOLD_PX) {
                                        handleMiniTap()
                                    }
                                },
                            )
                        }
                ) {
                    OverlayMiniContent(
                        model = model,
                        onTap = { handleMiniTap() },
                        onTimeout = {
                            viewModel.onAction(OverlayAction.CTAClicked("timeout", emptyMap()))
                        },
                    )
                }
            }
        }
        overlayWindowManager.showMini(composeView)
    }

    /**
     * Handle tap on the mini overlay: dismiss overlay, bring app to foreground,
     * then stop the service. Order matters — dismiss sets ViewModel state to Idle
     * so isActive() returns false BEFORE the activity resumes and queries state.
     */
    private fun handleMiniTap() {
        viewModel.onAction(OverlayAction.Dismiss("mini_tap"))
        bringAppToForeground()
        stopSelf()
    }

    private fun bringAppToForeground() {
        try {
            val intent = packageManager.getLaunchIntentForPackage(packageName)
            intent?.flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK or
                    android.content.Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
            if (intent != null) startActivity(intent)
        } catch (e: Exception) {
            android.util.Log.e("OverlayService", "Failed to bring app to foreground: ${e.message}")
        }
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Overlay Service",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            setShowBadge(false)
        }
        val nm = getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(channel)
    }

    /** Launch Google Maps walking navigation. Validates coordinate ranges first. */
    private fun launchMapsNavigation(lat: Double, lng: Double) {
        if (lat !in -90.0..90.0 || lng !in -180.0..180.0) {
            android.util.Log.e("OverlayService", "Invalid coordinates: lat=$lat, lng=$lng")
            return
        }
        try {
            val gmmIntentUri = android.net.Uri.parse("google.navigation:q=$lat,$lng&mode=w")
            val mapIntent = android.content.Intent(android.content.Intent.ACTION_VIEW, gmmIntentUri).apply {
                setPackage("com.google.android.apps.maps")
                flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK
            }
            if (mapIntent.resolveActivity(packageManager) != null) {
                startActivity(mapIntent)
            } else {
                // Fallback: open in browser
                val browserUri = android.net.Uri.parse(
                    "https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=walking"
                )
                val browserIntent = android.content.Intent(android.content.Intent.ACTION_VIEW, browserUri).apply {
                    flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(browserIntent)
            }
        } catch (e: Exception) {
            android.util.Log.e("OverlayService", "Failed to launch Maps: ${e.message}")
        }
    }

    /**
     * Recursively converts a [Bundle] to a [Map] for passing to [OverlayConfig.fromMap].
     * Depth-limited to [BUNDLE_MAX_DEPTH] to prevent stack overflow from
     * hypothetical circular references in the Bundle.
     */
    private fun bundleToMap(bundle: Bundle?, depth: Int = 0): Map<String, Any?> {
        if (bundle == null || depth > BUNDLE_MAX_DEPTH) return emptyMap()
        val map = mutableMapOf<String, Any?>()
        for (key in bundle.keySet()) {
            when (val value = bundle.get(key)) {
                is Bundle -> map[key] = bundleToMap(value, depth + 1)
                is ArrayList<*> -> map[key] = value.map { item ->
                    if (item is Bundle) bundleToMap(item, depth + 1) else item
                }
                else -> map[key] = value
            }
        }
        return map
    }
}
