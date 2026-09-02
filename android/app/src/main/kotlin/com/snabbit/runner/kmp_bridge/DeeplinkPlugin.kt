package com.snabbit.runner.kmp_bridge

import android.os.Handler
import android.os.Looper
import com.snabbit.runner.shared.core.deeplink.DeeplinkDispatcher
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.koin.core.component.KoinComponent
import org.koin.core.component.inject

/**
 * Bridges AppsFlyer OneLink (UDL) params resolved in the KMP shared module to
 * Flutter. Mirrors [AuthPlugin]'s MethodChannel + EventChannel pattern.
 *
 *  - `com.snabbit.runner/deeplink`        MethodChannel — `getInitialDeeplink`
 *  - `com.snabbit.runner/deeplink_events` EventChannel  — resolved param maps
 *
 * UDL resolves asynchronously, sometimes before Dart attaches the stream. The
 * [DeeplinkDispatcher] retains such an early link; `getInitialDeeplink` drains
 * it once at cold start. Once the stream is attached, links flow through the
 * EventChannel. The dispatcher guarantees a link is delivered exactly once
 * (either via the stream or via getInitialDeeplink, never both).
 *
 * Threading: UDL callbacks land on the main looper; the EventSink is fed via
 * [mainHandler] so `success` always runs on main.
 */
class DeeplinkPlugin : FlutterPlugin, EventChannel.StreamHandler, KoinComponent {

    private val deeplinkDispatcher: DeeplinkDispatcher by inject()

    private val mainHandler = Handler(Looper.getMainLooper())
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var sink: EventChannel.EventSink? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL).apply {
            setMethodCallHandler(::handleMethod)
        }
        eventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL).apply {
            setStreamHandler(this@DeeplinkPlugin)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        eventChannel?.setStreamHandler(null)
        eventChannel = null
        deeplinkDispatcher.setEmitter(null)
        sink = null
    }

    private fun handleMethod(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getInitialDeeplink" -> result.success(deeplinkDispatcher.consumePending())
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
        deeplinkDispatcher.setEmitter { params ->
            mainHandler.post { sink?.success(params) }
        }
    }

    override fun onCancel(arguments: Any?) {
        deeplinkDispatcher.setEmitter(null)
        sink = null
    }

    private companion object {
        const val METHOD_CHANNEL = "com.snabbit.runner/deeplink"
        const val EVENT_CHANNEL = "com.snabbit.runner/deeplink_events"
    }
}
