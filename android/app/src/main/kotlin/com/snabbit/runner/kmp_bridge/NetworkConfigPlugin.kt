package com.snabbit.runner.kmp_bridge

import com.snabbit.runner.shared.core.network.NetworkConfigStore
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.koin.core.component.KoinComponent
import org.koin.core.component.inject

/**
 * Owns the `com.snabbit.runner/network_config` MethodChannel.
 *
 * Pure config writer: Dart pushes `baseUrl` + `versionCode` at cold start
 * and on remote-config changes. The push opens [NetworkConfigStore]'s
 * init gate so subsequent HTTP calls can resolve their URL.
 *
 * Stateless on its own — all state lives in [NetworkConfigStore].
 * Validation rejects blank values because a blank `baseUrl` would
 * silently wedge every HTTP call (`awaitReady()` only releases when
 * `baseUrl.isNotBlank()`).
 */
class NetworkConfigPlugin : FlutterPlugin, KoinComponent {

    private val configStore: NetworkConfigStore by inject()

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
                val baseUrl = call.argument<String>("baseUrl")?.trim()
                val versionCode = call.argument<String>("versionCode")?.trim()
                // Optional — only the onboarding-host calls (e.g. PAN update) need it;
                // blank just means those calls can't run until it's been pushed.
                val onboardingUrl = call.argument<String>("onboardingUrl")?.trim().orEmpty()
                // Optional Profile-footer values (app-version label + prod flag).
                val appVersion = call.argument<String>("appVersion")?.trim().orEmpty()
                val isProd = call.argument<Boolean>("isProd") ?: true
                if (baseUrl.isNullOrBlank() || versionCode.isNullOrBlank()) {
                    result.error(
                        "INVALID_ARGS",
                        "pushConfig requires non-blank baseUrl + versionCode",
                        null,
                    )
                    return
                }
                configStore.pushNetworkConfig(baseUrl, versionCode, onboardingUrl, appVersion, isProd)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private companion object {
        const val CHANNEL = "com.snabbit.runner/network_config"
    }
}
