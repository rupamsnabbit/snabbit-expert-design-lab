package com.snabbit.runner.compose_overlay.data

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import com.snabbit.runner.compose_overlay.domain.OverlayAction
import com.snabbit.runner.compose_overlay.service.OverlayService
import android.content.Intent

/**
 * Bridge between Flutter (Dart) and the native overlay system.
 *
 * Exposes a [MethodChannel] for request/response calls (show, dismiss,
 * check permission) and an [EventChannel] for streaming lifecycle events
 * back to Flutter.
 *
 * Created by [ComposeOverlayPlugin] when the FlutterEngine attaches and
 * torn down via [dispose] when it detaches.
 */
class OverlayChannelManager(
    messenger: BinaryMessenger,
    private val context: Context,
) {
    companion object {
        private const val METHOD_CHANNEL = "com.snabbit.runner/compose_overlay/methods"
        private const val EVENT_CHANNEL = "com.snabbit.runner/compose_overlay/events"
        /** Maximum number of retry attempts when waiting for OverlayService to start. */
        private const val MAX_WIRE_RETRIES = 5
        /** Delay between retry attempts in milliseconds. */
        private const val WIRE_RETRY_DELAY_MS = 100L
    }

    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL)
    private val eventChannel = EventChannel(messenger, EVENT_CHANNEL)
    private var eventSink: EventChannel.EventSink? = null
    private var serviceManager: OverlayServiceManager = OverlayServiceManager(context)

    // Retry handler state — tracked so pending retries can be cancelled on dispose.
    private val retryHandler = Handler(Looper.getMainLooper())
    private var pendingRetryRunnable: Runnable? = null

    init {
        setupMethodChannel()
        setupEventChannel()
    }

    private fun setupMethodChannel() {
        methodChannel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "showOverlay" -> {
                        if (!Settings.canDrawOverlays(context)) {
                            result.error("PERMISSION_DENIED", "Overlay permission not granted", null)
                            return@setMethodCallHandler
                        }
                        @Suppress("UNCHECKED_CAST")
                        val args = call.arguments as? Map<String, Any?> ?: emptyMap()
                        val type = args["type"] as? String ?: "dialog"
                        serviceManager.startOverlay(type, args)
                        wireViewModelCallbacks()
                        result.success(null)
                    }

                    "showBanner" -> {
                        if (!Settings.canDrawOverlays(context)) {
                            result.error("PERMISSION_DENIED", "Overlay permission not granted", null)
                            return@setMethodCallHandler
                        }
                        @Suppress("UNCHECKED_CAST")
                        val args = call.arguments as? Map<String, Any?> ?: emptyMap()
                        serviceManager.startOverlay("banner", args)
                        wireViewModelCallbacks()
                        result.success(null)
                    }

                    "dismissOverlay" -> {
                        serviceManager.dismissOverlay()
                        result.success(null)
                    }

                    "updateBanner" -> {
                        @Suppress("UNCHECKED_CAST")
                        val args = call.arguments as? Map<String, Any?> ?: emptyMap()
                        val message = args["message"] as? String ?: ""
                        val type = args["type"] as? String ?: "info"
                        OverlayService.instance?.viewModel?.onAction(
                            OverlayAction.UpdateBanner(message, type)
                        )
                        result.success(null)
                    }

                    "checkOverlayPermission" -> {
                        result.success(Settings.canDrawOverlays(context))
                    }

                    "requestOverlayPermission" -> {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:${context.packageName}"),
                        ).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        context.startActivity(intent)
                        result.success(null)
                    }

                    "isOverlayVisible" -> {
                        result.success(serviceManager.isActive())
                    }

                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                sendError("WINDOW_MANAGER_ERROR", e.message ?: "Unknown error", e.stackTraceToString())
                result.error("WINDOW_MANAGER_ERROR", e.message, e.stackTraceToString())
            }
        }
    }

    private fun setupEventChannel() {
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }

    /**
     * Wire ViewModel callbacks so the native overlay can communicate back to
     * Flutter (method calls + event stream).
     *
     * The OverlayService starts asynchronously, so the ViewModel may not be
     * available immediately. Retries up to [MAX_WIRE_RETRIES] times with a
     * [WIRE_RETRY_DELAY_MS] delay. Pending retries are cancelled on [dispose]
     * to prevent dangling handler callbacks.
     */
    fun wireViewModelCallbacks(retryCount: Int = 0) {
        // Cancel any pending retry from a previous call.
        cancelPendingRetry()

        val vm = OverlayService.instance?.viewModel
        if (vm == null) {
            if (retryCount < MAX_WIRE_RETRIES) {
                android.util.Log.d("OverlayChannelManager", "Service not ready, retry ${retryCount + 1}/$MAX_WIRE_RETRIES")
                val runnable = Runnable { wireViewModelCallbacks(retryCount + 1) }
                pendingRetryRunnable = runnable
                retryHandler.postDelayed(runnable, WIRE_RETRY_DELAY_MS)
            } else {
                android.util.Log.w("OverlayChannelManager", "Service not ready after $MAX_WIRE_RETRIES retries — relying on OverlayService.onCreate wiring")
            }
            return
        }
        vm.onSendToFlutter = { method, args ->
            try {
                methodChannel.invokeMethod(method, args)
            } catch (e: Exception) {
                android.util.Log.w("OverlayChannelManager", "Failed to send '$method' to Flutter: ${e.message}")
            }
        }
        vm.onEmitEvent = { event, payload ->
            emitEvent(event, payload)
        }
        android.util.Log.d("OverlayChannelManager", "ViewModel callbacks wired successfully")
    }

    fun sendToFlutter(method: String, args: Map<String, Any?>) {
        try {
            methodChannel.invokeMethod(method, args)
        } catch (e: Exception) {
            android.util.Log.w("OverlayChannelManager", "sendToFlutter '$method' failed: ${e.message}")
        }
    }

    fun emitEvent(event: String, payload: Map<String, Any?>) {
        val eventData = mutableMapOf<String, Any?>("event" to event)
        eventData.putAll(payload)
        try {
            eventSink?.success(eventData)
        } catch (e: Exception) {
            android.util.Log.w("OverlayChannelManager", "emitEvent '$event' failed: ${e.message}")
        }
    }

    private fun sendError(code: String, message: String, stackTrace: String? = null) {
        sendToFlutter("onOverlayError", mapOf(
            "code" to code,
            "message" to message,
            "stackTrace" to stackTrace,
        ))
        emitEvent("error", mapOf("code" to code, "message" to message))
    }

    private fun cancelPendingRetry() {
        pendingRetryRunnable?.let { retryHandler.removeCallbacks(it) }
        pendingRetryRunnable = null
    }

    fun dispose() {
        cancelPendingRetry()
        methodChannel.setMethodCallHandler(null)
        eventSink = null
    }
}
