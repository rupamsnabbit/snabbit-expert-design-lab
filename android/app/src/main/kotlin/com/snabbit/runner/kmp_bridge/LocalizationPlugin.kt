package com.snabbit.runner.kmp_bridge

import com.snabbit.runner.shared.core.localization.LocalizationStore
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.koin.core.component.KoinComponent
import org.koin.core.component.inject

/**
 * Owns the `com.snabbit.runner/localization` MethodChannel.
 *
 * Pure writer: Dart's `LanguageProvider` pushes the server-driven i18n map
 * (key → translated string) + current language on every language settle
 * (cold-start restore + each change). The push lands in [LocalizationStore] —
 * the read model KMP / Compose Multiplatform surfaces look copy up against.
 *
 * Stateless on its own — all state lives in [LocalizationStore], which keeps the
 * last good snapshot on a malformed payload, so the plugin only forwards bytes.
 */
class LocalizationPlugin : FlutterPlugin, KoinComponent {

    private val store: LocalizationStore by inject()

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
            "pushMessages" -> {
                val language = call.argument<String>("language").orEmpty()
                val messagesJson = call.argument<String>("messagesJson")
                if (messagesJson.isNullOrBlank()) {
                    result.error(
                        "INVALID_ARGS",
                        "pushMessages requires a non-blank messagesJson",
                        null,
                    )
                    return
                }
                store.pushMessages(language, messagesJson)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private companion object {
        const val CHANNEL = "com.snabbit.runner/localization"
    }
}
