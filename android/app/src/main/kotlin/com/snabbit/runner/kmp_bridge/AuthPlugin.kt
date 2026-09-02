package com.snabbit.runner.kmp_bridge

import android.os.Handler
import android.os.Looper
import com.snabbit.runner.shared.core.AppDispatchers
import com.snabbit.runner.shared.core.Logger
import com.snabbit.runner.shared.core.network.UnauthorizedDispatcher
import com.snabbit.runner.shared.core.storage.StoreManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
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
 * Owns both auth-related channels:
 *
 *  - `com.snabbit.runner/auth`        MethodChannel — `pushToken`, `clearToken`
 *  - `com.snabbit.runner/auth_events` EventChannel  — typed events:
 *                                                     `{"type": "unauthorized"}`
 *
 * One plugin spans two channels because the underlying state is coupled:
 * a 401 event triggers a token clear; a fresh token push resets the
 * 401-debounce window. Splitting these across plugins would force
 * cross-plugin coordination for no benefit.
 *
 * Event-channel lifecycle: emitter is installed on `onListen` (Dart side
 * starts listening) and cleared on `onCancel`. While no Dart listener is
 * attached, observed 401s are dropped — acceptable because Dart's
 * `handle403` is only meaningful when the app is alive and listening.
 *
 * Threading: `pushToken` / `clearToken` perform disk I/O via the suspending
 * [StoreManager]. Handlers launch on [AppDispatchers.io] and post the
 * MethodChannel `Result` back to the main thread via [mainHandler] — the
 * binder thread that invoked the handler is never blocked on disk. The
 * same [mainHandler] feeds the EventChannel sink so `EventSink.success`
 * always runs on main.
 */
class AuthPlugin : FlutterPlugin, EventChannel.StreamHandler, KoinComponent {

    private val storeManager: StoreManager by inject()
    private val unauthorizedDispatcher: UnauthorizedDispatcher by inject()
    private val dispatchers: AppDispatchers by inject()
    private val logger: Logger by inject()

    private val mainHandler = Handler(Looper.getMainLooper())
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var sink: EventChannel.EventSink? = null
    private var scope: CoroutineScope? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        scope = CoroutineScope(SupervisorJob() + dispatchers.io)
        methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL).apply {
            setMethodCallHandler(::handleMethod)
        }
        eventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL).apply {
            setStreamHandler(this@AuthPlugin)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        scope?.cancel()
        scope = null
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        eventChannel?.setStreamHandler(null)
        eventChannel = null
        unauthorizedDispatcher.setEmitter(null)
        sink = null
    }

    private fun handleMethod(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pushToken" -> {
                val token = call.argument<String>("token")
                if (token.isNullOrBlank()) {
                    result.error("INVALID_ARGS", "pushToken requires non-blank token", null)
                    return
                }
                launchPersistence(result, "pushToken") {
                    storeManager.pushToken(token)
                }
            }
            "clearToken" -> {
                launchPersistence(result, "clearToken") {
                    storeManager.clearToken()
                }
            }
            else -> result.notImplemented()
        }
    }

    /**
     * Runs [op] on the plugin's IO-scoped coroutine and bridges the outcome
     * back to the MethodChannel `Result` on the main thread. Surfaces disk
     * write failures as `PERSIST_FAILED` so the Dart side can react
     * (retry, force re-login, surface to user) rather than silently
     * trusting that the value was written.
     */
    private fun launchPersistence(
        result: MethodChannel.Result,
        opName: String,
        op: suspend () -> Unit,
    ) {
        val active = scope ?: run {
            result.error("BRIDGE_DETACHED", "AuthPlugin not attached", null)
            return
        }
        active.launch {
            try {
                op()
                mainHandler.post { result.success(null) }
            } catch (e: CancellationException) {
                // Scope teardown in onDetachedFromEngine cancels in-flight
                // work — propagate so the structured-concurrency contract
                // stands and we don't surface a spurious PERSIST_FAILED to
                // Dart during normal lifecycle transitions.
                throw e
            } catch (e: Exception) {
                logger.e(TAG, "$opName persist failed", e)
                mainHandler.post {
                    result.error("PERSIST_FAILED", "$opName failed: ${e.message}", null)
                }
            }
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
        unauthorizedDispatcher.setEmitter {
            mainHandler.post {
                sink?.success(mapOf("type" to "unauthorized"))
            }
        }
    }

    override fun onCancel(arguments: Any?) {
        unauthorizedDispatcher.setEmitter(null)
        sink = null
    }

    private companion object {
        const val METHOD_CHANNEL = "com.snabbit.runner/auth"
        const val EVENT_CHANNEL = "com.snabbit.runner/auth_events"
        const val TAG = "AuthPlugin"
    }
}
