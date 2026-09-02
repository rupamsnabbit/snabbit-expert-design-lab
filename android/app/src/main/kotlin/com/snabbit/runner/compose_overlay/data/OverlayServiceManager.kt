package com.snabbit.runner.compose_overlay.data

import android.content.Context
import android.content.Intent
import android.os.Bundle
import com.snabbit.runner.compose_overlay.service.OverlayService

/**
 * Manages the lifecycle of [OverlayService] — starting, stopping, and
 * checking active state. Converts Flutter-side config [Map]s into [Bundle]s
 * for the service intent extras.
 *
 * Used by [OverlayChannelManager] to translate MethodChannel calls into
 * service start/stop intents.
 */
class OverlayServiceManager(private val context: Context) {

    /** Start (or update) the overlay service with the given type and config. */
    fun startOverlay(type: String, configMap: Map<String, Any?>) {
        val intent = Intent(context, OverlayService::class.java).apply {
            action = OverlayService.ACTION_SHOW
            putExtra(OverlayService.EXTRA_TYPE, type)
            putExtra(OverlayService.EXTRA_CONFIG, mapToBundle(configMap))
        }
        context.startForegroundService(intent)
    }

    /** Send a DISMISS intent to stop the overlay and the foreground service. */
    fun dismissOverlay() {
        val intent = Intent(context, OverlayService::class.java).apply {
            action = OverlayService.ACTION_DISMISS
        }
        context.startService(intent)
    }

    fun stopService() {
        context.stopService(Intent(context, OverlayService::class.java))
    }

    /** Whether the overlay service is running and actively showing a view. */
    fun isActive(): Boolean = OverlayService.instance?.viewModel?.isActive() == true

    /**
     * Recursively converts a Kotlin [Map] to an Android [Bundle] for passing
     * via [Intent] extras. This is the inverse of [OverlayService.bundleToMap].
     *
     * Required because Android Intents only support [Bundle], not arbitrary Maps.
     * The round-trip is: Flutter Dart Map → MethodChannel → Kotlin Map →
     * [mapToBundle] → Intent Bundle → [OverlayService.bundleToMap] → OverlayConfig.
     */
    private fun mapToBundle(map: Map<String, Any?>): Bundle {
        val bundle = Bundle()
        for ((key, value) in map) {
            when (value) {
                is String -> bundle.putString(key, value)
                is Int -> bundle.putInt(key, value)
                is Long -> bundle.putLong(key, value)
                is Double -> bundle.putDouble(key, value)
                is Boolean -> bundle.putBoolean(key, value)
                is Map<*, *> -> {
                    @Suppress("UNCHECKED_CAST")
                    bundle.putBundle(key, mapToBundle(value as Map<String, Any?>))
                }
                is List<*> -> {
                    val arrayList = ArrayList<Bundle>()
                    for (item in value) {
                        if (item is Map<*, *>) {
                            @Suppress("UNCHECKED_CAST")
                            arrayList.add(mapToBundle(item as Map<String, Any?>))
                        }
                    }
                    bundle.putParcelableArrayList(key, arrayList)
                }
                null -> {}
            }
        }
        return bundle
    }
}
