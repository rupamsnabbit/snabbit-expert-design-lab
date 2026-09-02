package com.snabbit.runner.kmp_bridge

import android.content.Context
import android.os.Bundle
import com.clevertap.android.sdk.CleverTapAPI
import com.snabbit.runner.shared.core.analytics.AnalyticsTracker
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.koin.core.component.KoinComponent
import org.koin.core.component.inject

/**
 * Bridges Dart analytics calls into the KMP [AnalyticsTracker]. One
 * MethodChannel — no EventChannels in v1 (no conversion / deep-link
 * payloads to push back to Dart; see LLD §5.5 / §11.1).
 *
 * Dart never specifies destinations. Every `track` call crosses and the
 * KMP-side `AnalyticsRouteTable` decides which providers receive it.
 * `identify`, `reset`, and `setUserProperty` are unrouted — they fan to
 * every registered provider (identity/profile is not routed).
 *
 * Tracker calls are synchronous fire-and-forget on the KMP side — every
 * provider call is wrapped in `runCatching` inside
 * `AnalyticsTrackerImpl`, so `result.success(null)` always.
 */
class AnalyticsPlugin : FlutterPlugin, KoinComponent {

    private val tracker: AnalyticsTracker by inject()

    private var channel: MethodChannel? = null
    private var appContext: Context? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler(::handle)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "track" -> {
                val name = call.argument<String>("name")
                if (name.isNullOrBlank()) {
                    result.error("INVALID_ARGS", "track requires non-blank name", null)
                    return
                }
                val props = call.argument<Map<String, Any?>>("props") ?: emptyMap()
                val targets = call.argument<List<String>>("targets")?.toSet()
                tracker.track(name, props, targets)
                result.success(null)
            }
            "identify" -> {
                tracker.identify(call.argument<String?>("userId"))
                result.success(null)
            }
            "reset" -> {
                tracker.reset()
                result.success(null)
            }
            "onUserLogin" -> {
                tracker.onUserLogin(call.argument<Map<String, Any?>>("profile") ?: emptyMap())
                result.success(null)
            }
            "setUserProperty" -> {
                val key = call.argument<String>("key")
                if (key.isNullOrBlank()) {
                    result.error("INVALID_ARGS", "setUserProperty requires non-blank key", null)
                    return
                }
                tracker.setUserProperty(key, call.argument<Any?>("value"))
                result.success(null)
            }
            "setUserProperties" -> {
                val props = call.argument<Map<String, Any?>>("props") ?: emptyMap()
                tracker.setUserProperties(props)
                result.success(null)
            }
            // Cross-event super-props store lives KMP-side so native/CMP events
            // (which never hit the Dart merge) also carry them. Dart still keeps
            // its own merge for its events; both feed the same values.
            "registerSuperProperties" -> {
                tracker.registerSuperProperties(call.argument<Map<String, Any?>>("props") ?: emptyMap())
                result.success(null)
            }
            "clearSuperProperties" -> {
                tracker.clearSuperProperties()
                result.success(null)
            }
            // CleverTap push (custom rendering): app draws via flutter_local_
            // notifications. "Viewed" is fired natively by SnabbitPushService
            // (background isolate has no MethodChannel); only click + token
            // round-trip through here.
            "ctPushClicked" -> {
                appContext?.let {
                    CleverTapAPI.getDefaultInstance(it)
                        ?.pushNotificationClickedEvent(bundleOf(call.argument("props")))
                }
                result.success(null)
            }
            "ctRegisterToken" -> {
                val token = call.argument<String>("token")
                appContext?.let { CleverTapAPI.getDefaultInstance(it)?.pushFcmRegistrationId(token, true) }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun bundleOf(props: Map<String, Any?>?): Bundle {
        val b = Bundle()
        props?.forEach { (k, v) -> b.putString(k, v?.toString()) }
        return b
    }

    private companion object {
        const val CHANNEL = "com.snabbit.runner/analytics"
    }
}
