package com.snabbit.runner.kmp_bridge

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * Per-concern Flutter plugin for the Language feature. Owns the
 * `com.snabbit.runner/language` MethodChannel used for the **native → Dart**
 * callbacks the Compose Language screen makes: [invokeFlutter] routes the
 * screen's save-apply (`applyLanguage`) and analytics (`trackLanguageEvent`) to
 * the Flutter side.
 *
 * The screen itself is opened as a native nav destination
 * (`KmpNavigationBridge.openNativeDestination("language", …)`), NOT by this
 * plugin — there is no `LanguageActivity` (single-Activity + NavHost model), so
 * this plugin no longer launches anything or handles a Dart → native call.
 *
 * [invokeFlutter] lives on the companion because the Compose screen runs in the
 * separate `NavigationHostActivity` (outside the Flutter engine) and routes back
 * through this engine-bound channel, held statically for the engine's lifetime
 * (one engine, one plugin instance).
 *
 * Registered via `MainActivity.configureFlutterEngine` (plugins.add).
 */
class LanguagePlugin : FlutterPlugin {

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        // Application context — safe to hold for the process lifetime (it IS the
        // Application). [writePendingLanguage] needs it to hand the chosen code to
        // Flutter reliably even while the Flutter engine is backgrounded behind
        // NavigationHostActivity, where [invokeFlutter] can drop or time out.
        appContext = binding.applicationContext
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = null
        // appContext is intentionally retained: it's the Application context (no
        // leak), and a pending-language write may need it after detach.
    }

    companion object {
        private const val CHANNEL = "com.snabbit.runner/language"

        /**
         * `shared_preferences` plugin's stable legacy-API file/key convention
         * (mirrors [RunnerStateCacheSeeder]). Flutter reads this key as
         * `pending_language_preference` — the plugin adds/strips the `flutter.` prefix.
         */
        private const val FLUTTER_PREFS_FILE = "FlutterSharedPreferences"
        private const val KEY_PENDING_LANGUAGE = "flutter.pending_language_preference"

        private var channel: MethodChannel? = null
        private var appContext: Context? = null

        private const val DEFAULT_TIMEOUT_MS = 15_000L

        /**
         * Routes [method] to the Flutter side and suspends until it replies.
         * Called from the Compose screen's gateway/analytics impls (which run in
         * `NavigationHostActivity`, a *separate* Activity). Throws
         * [FlutterBridgeException] if the Flutter handler returns an error, or on
         * timeout.
         *
         * Hardening:
         *  - `withContext(Main)` — `invokeMethod` must run on the platform thread;
         *    confine it here so a caller that switches dispatcher can't break it.
         *  - `withTimeout` — the host engine is backgrounded while the native host
         *    is foreground; if the OS reclaims it mid-round-trip, no reply ever
         *    comes. The timeout is surfaced as a NON-cancellation
         *    [FlutterBridgeException] so the caller's `catch (Throwable)` recovers
         *    instead of the coroutine hanging forever.
         *  - `isActive` guards — a late reply on a timed-out call no-ops.
         */
        suspend fun invokeFlutter(
            method: String,
            arguments: Any?,
            timeoutMs: Long = DEFAULT_TIMEOUT_MS,
        ): Any? = try {
            withTimeout(timeoutMs) {
                withContext(Dispatchers.Main) {
                    suspendCancellableCoroutine { cont ->
                        val ch = channel ?: run {
                            cont.resumeWithException(
                                IllegalStateException("LanguagePlugin not attached"),
                            )
                            return@suspendCancellableCoroutine
                        }
                        ch.invokeMethod(method, arguments, object : MethodChannel.Result {
                            override fun success(value: Any?) {
                                if (cont.isActive) cont.resume(value)
                            }

                            override fun error(code: String, message: String?, details: Any?) {
                                if (cont.isActive) {
                                    cont.resumeWithException(FlutterBridgeException(code, message))
                                }
                            }

                            override fun notImplemented() {
                                if (cont.isActive) {
                                    cont.resumeWithException(
                                        IllegalStateException("Flutter has no handler for '$method'"),
                                    )
                                }
                            }
                        })
                    }
                }
            }
        } catch (e: TimeoutCancellationException) {
            throw FlutterBridgeException(
                "BRIDGE_TIMEOUT",
                "Flutter did not reply to '$method' within ${timeoutMs}ms",
            )
        }

        /**
         * Reliably hands an already-persisted language [code] to Flutter by writing
         * it to the shared_preferences-backed `FlutterSharedPreferences` file. Unlike
         * [invokeFlutter] — a live round-trip into a Flutter engine that is
         * *backgrounded* while the Compose Language screen (NavigationHostActivity) is
         * foreground, so it can be dropped or time out — this is a synchronous local
         * write that survives backgrounding. Flutter reconciles from it on its next
         * `resumed` lifecycle event (`LanguageChannel.reconcilePendingLanguage`).
         *
         * `apply()` (not `commit()`) avoids main-thread disk I/O; Android's QueuedWork
         * flushes the pending write when the host Activity stops, so the value is
         * durable before Flutter resumes. Best-effort — returns false (never throws)
         * if no context is available yet.
         */
        fun writePendingLanguage(code: String): Boolean {
            val ctx = appContext ?: return false
            return try {
                ctx.getSharedPreferences(FLUTTER_PREFS_FILE, Context.MODE_PRIVATE)
                    .edit()
                    .putString(KEY_PENDING_LANGUAGE, code)
                    .apply()
                true
            } catch (t: Throwable) {
                false
            }
        }
    }
}

/** Raised when a Flutter-side handler returns an error to [LanguagePlugin.invokeFlutter]. */
class FlutterBridgeException(
    val code: String,
    message: String?,
) : Exception(message ?: code)
