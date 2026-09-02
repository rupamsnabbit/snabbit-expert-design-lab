package com.snabbit.runner.kmp_bridge

import com.snabbit.runner.shared.core.appconfig.AppConfigStore
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.koin.core.component.KoinComponent
import org.koin.core.component.inject

/**
 * Owns the `com.snabbit.runner/app_config` MethodChannel — the bridge that
 * mirrors the Flutter app-config document (`GlobalState.setAppConfig()`'s
 * startup fetch) into the KMP [AppConfigStore] so :shared features can decode
 * their config slices (first consumer: the delayed check-in FR-11
 * `job_support` options).
 *
 * One direction only (Dart → KMP): app config is fetched once at startup with
 * no retry (#421), so there is no KMP-initiated refresh — `RunnerStatePlugin`
 * is the bidirectional sibling if that ever changes. Synchronous
 * `MutableStateFlow.value` write, no main-thread hop needed.
 */
class AppConfigPlugin : FlutterPlugin, KoinComponent {

    private val store: AppConfigStore by inject()

    private var channel: MethodChannel? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
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
            "pushConfig" -> {
                val json = call.argument<String>("json")
                if (json.isNullOrBlank()) {
                    result.error("INVALID_ARGS", "pushConfig requires non-blank json", null)
                    return
                }
                store.pushConfig(json)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private companion object {
        const val CHANNEL = "com.snabbit.runner/app_config"
    }
}
