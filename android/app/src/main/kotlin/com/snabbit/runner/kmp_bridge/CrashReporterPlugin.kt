package com.snabbit.runner.kmp_bridge

import android.os.Handler
import android.os.Looper
import android.util.Log
import com.google.firebase.crashlytics.FirebaseCrashlytics
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel

/**
 * Bridges KMP-side `CrashReporter.report(throwable, meta)` calls to the
 * Dart `MonitoringServiceHelper.logError` pipeline. Mirror-image of
 * [AnalyticsPlugin]: Kotlin invokes the channel; Dart handles.
 *
 * The companion's [active] channel is the single source of truth; any
 * KMP caller can resolve it via [report] without Koin injection, which
 * matters because the reporter lambda is captured by KmpBootstrap into
 * Koin singletons that outlive plugin attach/detach cycles.
 *
 * Calling [report] before the plugin attaches to an engine — i.e.
 * during the `Application.onCreate` → first `MainActivity` window —
 * falls back to Crashlytics directly ([reportPreEngine]). That window is
 * not an edge case: every `KmpBootstrap` report lands in it (hydrateAll,
 * remoteConfigFetch, encryptedStoreInit), so routing it only through the
 * Dart channel meant those were logged to Logcat and dropped.
 */
class CrashReporterPlugin : FlutterPlugin {

    private var channel: MethodChannel? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).also { active = it }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        if (active === channel) active = null
        channel = null
    }

    companion object {
        private const val CHANNEL = "com.snabbit.runner/crash_reporter"
        private const val TAG = "CrashReporterPlugin"
        private const val MAX_STACK_LEN = 4096
        private val main = Handler(Looper.getMainLooper())

        @Volatile private var active: MethodChannel? = null

        /**
         * Function reference that satisfies the
         * `(Throwable, Map<String, String>) -> Unit` shape
         * `KmpBootstrap.initialize` expects. Marshals onto the main
         * thread (MethodChannel contract) and falls back to Logcat if
         * no engine is attached yet.
         */
        fun report(throwable: Throwable, meta: Map<String, String>) {
            val ch = active
            if (ch == null) {
                reportPreEngine(throwable, meta)
                return
            }
            val payload = mapOf(
                "op" to (meta["op"] ?: "unknown"),
                "exception" to (throwable::class.java.simpleName ?: "Throwable"),
                "message" to (throwable.message ?: ""),
                "stackTrace" to throwable.stackTraceToString().take(MAX_STACK_LEN),
                "meta" to meta,
            )
            main.post {
                runCatching { ch.invokeMethod("report", payload) }
                    .onFailure { Log.e(TAG, "invokeMethod failed", it) }
            }
        }

        /**
         * No engine yet — report straight to Crashlytics instead of dropping.
         *
         * Crashlytics initialises from its own ContentProvider, which runs BEFORE
         * `Application.onCreate`, so it is available at exactly the moment the
         * Dart channel is not. This is the only sink for anything reported during
         * bootstrap.
         *
         * `meta` becomes custom keys rather than being folded into the message, so
         * Crashlytics groups these by stack trace: one issue per real fault, with
         * the op as a filterable dimension. Without that, a rising rate of (say)
         * encrypted-store recoveries would be indistinguishable from noise.
         *
         * Non-fatal: the app is still running. Everything is best-effort — a
         * reporting path must never itself break launch.
         */
        private fun reportPreEngine(throwable: Throwable, meta: Map<String, String>) {
            Log.e(TAG, "no engine attached; reporting to Crashlytics: $meta", throwable)
            runCatching {
                FirebaseCrashlytics.getInstance().apply {
                    setCustomKey("kmp_pre_engine", true)
                    meta.forEach { (k, v) -> setCustomKey(k, v) }
                    recordException(throwable)
                }
            }.onFailure { Log.e(TAG, "Crashlytics fallback failed", it) }
        }
    }
}
