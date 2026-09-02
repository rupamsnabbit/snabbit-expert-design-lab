package com.snabbit.runner.kmp_bridge

import android.os.Handler
import android.os.Looper
import com.snabbit.runner.shared.features.periodleave.PeriodLeaveStore
import com.snabbit.runner.shared.features.profile.RunnerProfileStore
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CompletableDeferred
import org.koin.core.component.KoinComponent
import org.koin.core.component.inject

/**
 * Owns the `com.snabbit.runner/profile_sync` MethodChannel — the bridge that mirrors the
 * Flutter-fetched `runners/me` (+ `period_leave/availability`) into the KMP
 * [RunnerProfileStore] / [PeriodLeaveStore]. While the app is still mostly Flutter, Dart
 * owns the single fetch and pushes the result; KMP does **not** fetch natively (that would
 * double the API load).
 *
 * Bidirectional:
 *  - **Dart → KMP:** `pushProfile` / `pushProfileError` / `pushPeriodLeave` write into the
 *    stores. `pushProfile` carries the raw `runners/me` body (KMP decodes it with the same
 *    DTO the native data source uses); `pushProfileError` surfaces the error state so the
 *    Profile screen shows it immediately (no timeout).
 *  - **KMP → Dart:** [RunnerProfileStore.requestRefresh] (Profile pull-to-refresh / retry)
 *    fires `requestRefresh`; Dart re-fetches + re-pushes, then replies on the channel
 *    `Result`. That reply completes the *suspending* [RunnerProfileStore.requestRefresh], so
 *    the refresh spinner clears exactly when Dart is done — even if the data is unchanged or
 *    the re-fetch failed. Bound on attach, cleared on detach. `invokeMethod` is posted to the
 *    main looper because Compose may call `requestRefresh` from any dispatcher.
 */
class ProfileSyncPlugin : FlutterPlugin, KoinComponent {

    private val profileStore: RunnerProfileStore by inject()
    private val periodLeaveStore: PeriodLeaveStore by inject()

    private var channel: MethodChannel? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler(::handle)
        }
        // Reverse-refresh: suspend until Dart finishes re-fetching + pushing (its channel
        // reply completes the deferred). Completes immediately if the channel is gone.
        profileStore.bind {
            val done = CompletableDeferred<Unit>()
            mainHandler.post {
                val ch = channel
                if (ch == null) {
                    done.complete(Unit)
                } else {
                    ch.invokeMethod(
                        "requestRefresh",
                        null,
                        object : MethodChannel.Result {
                            override fun success(result: Any?) { done.complete(Unit) }
                            override fun error(code: String, message: String?, details: Any?) { done.complete(Unit) }
                            override fun notImplemented() { done.complete(Unit) }
                        },
                    )
                }
            }
            done.await()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        profileStore.bind(null)
        channel?.setMethodCallHandler(null)
        channel = null
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pushProfile" -> {
                val json = call.argument<String>("json")
                if (json.isNullOrBlank()) {
                    result.error("INVALID_ARGS", "pushProfile requires non-blank json", null)
                    return
                }
                profileStore.pushProfile(json)
                result.success(null)
            }
            "pushProfileError" -> {
                profileStore.pushProfileError(call.argument<String>("message"))
                result.success(null)
            }
            "pushPeriodLeave" -> {
                val json = call.argument<String>("json")
                if (json.isNullOrBlank()) {
                    result.error("INVALID_ARGS", "pushPeriodLeave requires non-blank json", null)
                    return
                }
                periodLeaveStore.pushPeriodLeave(json)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private companion object {
        const val CHANNEL = "com.snabbit.runner/profile_sync"
    }
}
