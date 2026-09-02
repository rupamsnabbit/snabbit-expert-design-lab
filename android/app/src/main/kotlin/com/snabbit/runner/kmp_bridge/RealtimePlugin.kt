package com.snabbit.runner.kmp_bridge

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.util.Log
import androidx.core.content.ContextCompat
import com.snabbit.runner.shared.core.background.SnabbitForegroundService
import com.snabbit.runner.shared.core.realtime.RealtimeConfigStore
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.koin.core.component.KoinComponent
import org.koin.core.component.inject

/**
 * Owns the `com.snabbit.runner/realtime` MethodChannel (WS4).
 *
 * Dart calls, in the order the LLD prescribes (§3.2 / §6.9):
 *  - "pushConfig" { mqttConfigJson: String? } — right after every runners/me
 *    (login + refresh). Null/absent config clears the store ⇒ polling cohort.
 *    Returns true iff realtime is enabled for this runner.
 *  - "start" — start the foreground service (login / app-open, enrolled path).
 *  - "wake" — FCM foreground hand-off (the killed path starts the service
 *    directly with the wake intent, no bridge — LLD §6.5).
 *  - "stop" — logout teardown.
 *  - "clearConfig" — logout: also drop the persisted last-known-good config.
 */
class RealtimePlugin : FlutterPlugin, KoinComponent {

    private val configStore: RealtimeConfigStore by inject()

    private var channel: MethodChannel? = null
    private var appContext: Context? = null
    private var scope: CoroutineScope? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler(::handle)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        scope?.cancel()
        scope = null
        appContext = null
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pushConfig" -> {
                val raw = call.argument<String>("mqttConfigJson")
                scope?.launch {
                    val enabled = withContext(Dispatchers.IO) { configStore.push(raw) }
                    result.success(enabled)
                } ?: result.error("DETACHED", "plugin not attached", null)
            }
            "start" -> { startService(SnabbitForegroundService.ACTION_START); result.success(null) }
            "wake" -> { startService(SnabbitForegroundService.ACTION_WAKE); result.success(null) }
            "stop" -> {
                appContext?.let { ctx ->
                    runCatching {
                        ctx.startService(serviceIntent(ctx, SnabbitForegroundService.ACTION_STOP))
                    }
                }
                result.success(null)
            }
            "clearConfig" -> {
                scope?.launch {
                    withContext(Dispatchers.IO) { configStore.clear() }
                    result.success(null)
                } ?: result.error("DETACHED", "plugin not attached", null)
            }
            // Feature #1: app-side Firebase RC kill-switch. Persist the flag + poll
            // cadence (read on cold-boot) and, if the engine is live, flip it now.
            "setMqttEnabled" -> {
                val enabled = call.argument<Boolean>("mqttEnabled") ?: true
                val pollSeconds = call.argument<Int>("pollIntervalSeconds") ?: 60
                val connectTimeoutSeconds = call.argument<Int>("connectTimeoutSeconds") ?: 25
                val postActionSeconds = call.argument<Int>("postActionTimeoutSeconds") ?: 5
                val healthAnalyticsEnabled = call.argument<Boolean>("healthAnalyticsEnabled") ?: true
                scope?.launch {
                    // Always complete the Result — a throw in pushAppConfig would
                    // otherwise hang the awaited Dart call on the login path. (Review #9.)
                    try {
                        withContext(Dispatchers.IO) {
                            configStore.pushAppConfig(enabled, pollSeconds, connectTimeoutSeconds, postActionSeconds, healthAnalyticsEnabled)
                        }
                        SnabbitForegroundService.activeEngine?.setMqttEnabled(enabled)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("SET_MQTT_ENABLED_FAILED", e.message, null)
                    }
                } ?: result.error("DETACHED", "plugin not attached", null)
            }
            else -> result.notImplemented()
        }
    }

    private fun startService(action: String) {
        val ctx = appContext ?: return
        // SnabbitForegroundService is a location-typed FGS (it hosts the realtime socket
        // and, post-migration, the periodic location upload). On Android 14+ startForeground
        // with a location type throws without a location permission — so never make the
        // startForegroundService promise we can't fulfil. Skip + log; realtime simply
        // doesn't run for a location-denied runner (who can't be dispatched jobs anyway),
        // and resumes on the next start once the permission is granted.
        if (!hasLocationPermission(ctx)) {
            Log.w(TAG, "realtime FGS start skipped ($action): location permission not granted")
            return
        }
        ContextCompat.startForegroundService(ctx, serviceIntent(ctx, action))
    }

    private fun hasLocationPermission(ctx: Context): Boolean =
        ContextCompat.checkSelfPermission(ctx, Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED ||
            ContextCompat.checkSelfPermission(ctx, Manifest.permission.ACCESS_COARSE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED

    private fun serviceIntent(ctx: Context, action: String) =
        Intent(ctx, SnabbitForegroundService::class.java).setAction(action)

    private companion object {
        const val CHANNEL = "com.snabbit.runner/realtime"
        const val TAG = "RealtimePlugin"
    }
}
