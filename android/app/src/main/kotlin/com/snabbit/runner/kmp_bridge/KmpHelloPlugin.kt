package com.snabbit.runner.kmp_bridge

import com.snabbit.runner.shared.core.AppDispatchers
import com.snabbit.runner.shared.core.Logger
import com.snabbit.runner.shared.hello.HelloModule
import com.snabbit.runner.shared.hello.helloModule
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import org.koin.core.component.KoinComponent
import org.koin.core.component.inject

/**
 * Debug-only bridge: exposes the KMP exemplar `HelloModule` to Dart so
 * the debug menu can verify the bridge is wired end-to-end. Owns the
 * single `com.snabbit.runner/kmp_hello` MethodChannel.
 *
 * Production code does not depend on this. Safe to delete once `HelloModule`
 * is retired.
 */
class KmpHelloPlugin : FlutterPlugin, KoinComponent {

    private val logger: Logger by inject()
    private val dispatchers: AppDispatchers by inject()
    private val hello: HelloModule by lazy { helloModule(logger, dispatchers) }

    private var channel: MethodChannel? = null
    private var scope: CoroutineScope? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        scope = CoroutineScope(SupervisorJob() + dispatchers.main)
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler(::handle)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        scope?.cancel()
        scope = null
        channel?.setMethodCallHandler(null)
        channel = null
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getHelloMessage" -> {
                val active = scope ?: run {
                    result.error("BRIDGE_DETACHED", "KmpHelloPlugin not attached", null)
                    return
                }
                active.launch {
                    try {
                        result.success(hello.getHelloMessage())
                    } catch (e: CancellationException) {
                        throw e
                    } catch (e: Exception) {
                        logger.e(TAG, "getHelloMessage failed", e)
                        result.error("HELLO_ERROR", e.message, null)
                    }
                }
            }
            else -> result.notImplemented()
        }
    }

    private companion object {
        const val CHANNEL = "com.snabbit.runner/kmp_hello"
        const val TAG = "KmpHelloPlugin"
    }
}
